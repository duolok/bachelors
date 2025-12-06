#import "../funkcije.typ": todo

= Имплементација
<имплементација>

Ово поглавље детаљно описује кључне аспекте имплементације, са фокусом на конкретна техничка 
решења, алгоритме и изазове. Приказани су најважнији делови кода са 
објашњењима имплементационих одлука и решењима специфичних проблема.

== Прикупљање системских метрика

Сви колектори читају податке из Linux `/proc` псеудо фајл 
система који пружа интерфејс ка `kernel` подацима. Свaki колектор имплементира `Collector` trait и ради асинхроно 
користећи Tokio runtime.

=== Читање из /proc фајл система

Linux `/proc` фајл систем пружа текстуални интерфејс ка kernel подацима. Иако изгледају као обични фајлови, 
подаци се генеришу динамички приликом читања. Читање се обавља асинхроно користећи `tokio::fs` модул:

#figure(
```rust
use tokio::fs;

async fn read_cpu_stats(&self) -> Result<Vec<CpuStates>, CollectorError> {
        let content = fs::read_to_string("/proc/stat")
            .await
            .map_err(|e| CollectorError::AccessError("/proc/stat".
            to_string(), e.to_string()))?;

        let mut stats: Vec<CpuStates> = Vec::new();

        for line in content.lines() {
            if line.starts_with("cpu") && line.chars().nth(3).map_or(false, |c| c.is_whitespace() || c.is_numeric()) {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() > 0 {
                    stats.push(CpuStates {
                        user: parts[1].parse().unwrap_or(0),
                        nice: parts[2].parse().unwrap_or(0),
                        system: parts[3].parse().unwrap_or(0),
                        idle: parts[4].parse().unwrap_or(0),
                        iowait: parts[5].parse().unwrap_or(0),
                        irq: parts[6].parse().unwrap_or(0),
                        softirq: parts[7].parse().unwrap_or(0),
                        steal: parts.get(8).and_then(|s| s.parse().ok()).unwrap_or(0),
                        guest: parts.get(9).and_then(|s| s.parse().ok()).unwrap_or(0),
                        guest_nice: parts.get(10).and_then(|s| s.parse().ok()).unwrap_or(0),
                    })
                }
            }
        }

        Ok(stats)
    }

```,
caption: [Асинхроно читање из /proc фајл система]
)

Овај приступ користи асинхрони I/O што омогућава да друге операције настављају док се чека на читање фајла. 
Грешке се мапирају у специјализоване типове грешака који садрже контекст о томе који фајл је узроковао проблем.

=== CPU метрике

CPU метрике се прикупљају читањем `/proc/stat` фајла који садржи агрегиране статистике за све CPU-ове у систему, 
као и појединачне статистике за сваки CPU. Формат је следећи:

```

cpu  74608 2520 24433 1117073 6176 4054 0 0 0 0
cpu0 37784 1260 12062 558377 3089 2027 0 0 0 0
cpu1 36824 1260 12371 558696 3087 2027 0 0 0 0


```



Свака линија садржи 10 бројева који представљају време (у јединицама од 1/100 секунде) проведено у различитим 
стањима: user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice.

CPU искоришћеност се не може одредити из једног мерења већ захтева два узастопна мерења и рачунање разлике. 
Алгоритам је следећи:


#figure(
```rust

    async fn calculate_usage(&self, current: &CpuStates,
    previous: &CpuStates) -> f32 {

        let prev_total = previous.user + previous.nice +
                        previous.system + previous.idle
                        + previous.iowait + previous.irq +
                        previous.softirq + previous.steal;

        let curr_total = current.user + current.nice 
                          + current.system + current.idle
                          + current.iowait + current.irq +
                          current.softirq + current.steal;

        let prev_idle = previous.idle + previous.iowait;
        let curr_idle = current.idle + current.iowait;

        let total_diff = curr_total.saturating_sub(prev_total);
        let idle_diff = curr_idle.saturating_sub(prev_idle);

        if total_diff == 0 {
            return 0.0;
        }

        let usage_diff = total_diff.saturating_sub(idle_diff);
        (usage_diff as f32 / total_diff as f32) * 100.0
    }

```,
caption: [Рачунање искоришћености процесора]
)

=== Метрике меморије

Информације о меморији се налазе у `/proc/meminfo` фајлу који садржи преко 40 различитих метрика. За 
ову имплментацију су релевантне следеће:
```
MemTotal:       16384000 kB
MemFree:         2048000 kB
MemAvailable:    8192000 kB
Buffers:          512000 kB
Cached:          4096000 kB
SwapTotal:       8192000 kB
SwapFree:        8000000 kB

```

Разлика између `MemFree` и `MemAvailable` је важна. `MemFree` показује потпуно некоришћену меморију, док 
`MemAvailable` укључује и меморију која се користи за cache али се може лако ослободити. За кориснике је 
`MemAvailable` релевантнија метрика јер показује колико меморије је заиста доступно за нове апликације.

=== Информације о процесима

Прикупљање информација о процесима је најкомплекснија операција јер захтева читање више фајлова за сваки процес. 
За сваки процес се читају следећи фајлови из `/proc/[pid]/` директоријума:

- `stat` — основне статистике (PID, име, стање, CPU време)
- `status` — детаљне информације (меморија, UID, GID)
- `cmdline` — комплетна командна линија
- `io` — I/O статистике (опционо, захтева root)


Прикупљање информација о процесима је I/O интензивна операција јер за 100 процеса треба прочитати најмање 300 
фајлова. Асинхрони приступ омогућава да се читања обављају паралелно, што значајно убрзава овај процес.


== Управљање процесима

Модул за управљање процесима омогућава слање различитих сигнала процесима и пружа заштиту од случајног гашења 
критичних системских процеса. За разлику од директног коришћења `libc::kill()` системског позива, имплементација 
користи `kill` команду преко Tokio-овог `Command` API-ја, што пружа бољу изолацију и безбедност.

#figure(
```rust
use tokio::process::Command;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessSignal {
    Kill,        // SIGKILL - принудно гашење
    Terminate,   // SIGTERM - љубазно гашење 
    Stop,        // SIGSTOP - паузирање процеса
    Continue,    // SIGCONT - наставак паузираног процеса
    Interrupt,   // SIGINT - прекид 
    Quit,        // SIGQUIT - излазак из процееса
    Custom(i32), // Произвољан сигнал број
}

```,
caption: [Рачунање искоришћености процесора]
)

=== Имплементација слања сигнала

Главна метода за слање сигнала користи `kill` команду преко Tokio-овог асинхроног Command API-ја. Овај приступ 
има неколико предности у односу на директно коришћење `libc::kill()`:

1. *Избегава несигуран код* — Не захтева unsafe блокове. 
2. *Боља изолација* — Користи постојећу `kill` команду која је добро тестирана.
3. *Флексибилност* — Лакше подржава различите опције и сигнале.
4. *Безбедност* — Kernel проверава дозволе независно од нашег кода.

У наставку слееди прикз конкретне методе за слање сигнала одређеном процесу:

#figure(
```rust

async fn send_signal(&self, pid: u32, signal: ProcessSignal) -> Result<ProcessActionResult, ProcessError> {
        let signal_name = match signal {
            ProcessSignal::Kill => "SIGKILL",
            ProcessSignal::Terminate => "SIGTERM",
            ProcessSignal::Stop => "SIGSTOP",
            ProcessSignal::Continue => "SIGCONT",
            ProcessSignal::Interrupt => "SIGINT",
            ProcessSignal::Quit => "SIGQUIT",
            ProcessSignal::Hangup => "SIGHUP",
            ProcessSignal::Custom(_) => "CUSTOM",
        };

        let process = self.get_process(pid).await?;
        if self.protected_processes.contains(&process.name) {
            return Err(ProcessError::PermissionDenied(pid));
        }
        let output = tokio::process::Command::new("kill")
            .arg(format!("-{}", signal_name))
            .arg(pid.to_string())
            .output()
            .await
            .map_err(|e| ProcessError::ActionFailed(
                "kill".to_string(),
                pid,
                e.to_string()
            ))?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(ProcessError::ActionFailed(
                "kill".to_string(),
                pid,
                stderr.to_string()
            ));
        }

        Ok(ProcessActionResult {
            pid,
            action: ProcessAction::Terminate,
            success: true,
            message: Some(format!("Sent {} to process {}",
            signal_name, pid)),
            timestamp: Utc::now(),
        })
    }
```,
caption: [Метода за слање сигнала одређеном процесу]
)

== Руковање грешкама

Иако је могуће ручно имплементирати типове за грешке, `thiserror` библиотека значајно поједностављује овај процес. 
Ова библиотека пружа proceduрални макро који аутоматски генерише имплементације потребних trait-ова за custom error типове.

`thiserror` пружа следеће могућности:

*#[error(...)]* атрибут — Дефинише поруку грешке са подршком за форматирање. Бројеви у витичастим заградама 
(`{0}`, `{1}`) се односе на поља enum варијанте.

*#[from]* атрибут — Аутоматски генерише `From` trait имплементацију, што омогућава коришћење `?` оператора за 
конверзију из једног типа грешке у други.

*{source}* конструкт — Користи се за приказивање угњеждених грешака.

Ова имплементација користи хијерархијску структуру грешака где `OxydError` представља главни error тип који обједињује 
све остале специјализоване типове грешака. Овај приступ пружа:

1. *Модуларност* — Сваки модул дефинише своје специфичне грешке
2. *Композицију* — Главни error тип може конвертовати све специјализоване грешке
3. *Детаљност* — Свака грешка садржи контекст специфичан за свој домен
4. *Propagaciju* — Аутоматска конверзија омогућава лако пропагирање грешака кроз слојеве

#figure(
```rust
#[derive(Error, Debug)]
pub enum OxydError {
    #[error("Collector  error: {0}")]
    Collector(#[from] CollectorError),

    #[error("Process manager error: {0}")]
    ProcessManager(#[from] ProcessError),

    #[error("Plugin error: {0}")]
    PluginError(#[from] PluginError),

    #[error("Configuration error: {0}")]
    ConfigError(#[from] ConfigError),

    #[error("IO error: {0}")]
    IOError(#[from] std::io::Error),

    #[error("Unknown error: {0}")]
    Unknown(String),
}
```,
caption: [Приказ имплементације главног коренског типа за грешке]
)

Затим сваки следћи подтип детаљније описује грешку која може настати у том слоју имплементације. 

#figure(
```rust
#[derive(Error, Debug)]
pub enum CollectorError {
    #[error("Failed to read system information: {0}")]
    SystemInfoError(String),

    #[error("Failed to access {0}: {1}")]
    AccessError(String, String),

    #[error("Parse error for {0}: {1}")]
    ParseError(String, String),

    #[error("Collector {0} not available on this system")]
    NotAvailable(String),

    #[error("Timeout while collecting {0}")]
    Timeout(String),
}
```,
caption: [Пример једне имплементације типа грешке]
)

== Асинхроно прикупљање метрика

Имплементација користи `tokio::join!` за асинхорно прикупљање свих метрика. Прикупљање 
метрика је приказано у наредном лиситнгу:

#figure(
```rust
async fn collect(&self) -> Result<SystemMetrics, CollectorError> {
        let (cpu_result, memory_result, process_result,
        network_result, disk_result)
        = tokio::join!(
            self.cpu_collector.collect(),
            self.memory_collector.collect(),
            self.process_collector.collect(),
            self.network_collector.collect(),  
            self.disk_collector.collect()     
        );

        let system_info = self.get_system_info().await;

        let cpu_metrics = cpu_result?.cpu;
        let memory_metrics = memory_result?.memory;
        let process_metrics = process_result?.processes;
        let network_metrics = network_result?.network;  
        let disk_metrics = disk_result?.disks;         

        Ok(SystemMetrics {
            timestamp: Utc::now(),
            system_info,
            cpu: cpu_metrics,
            memory: memory_metrics,
            disks: disk_metrics,        
            network: network_metrics,  
            processes: process_metrics,
        })
    }
```,
caption: [Прикупљање свих метрика система]
)


== Кориснички интерфејс

Кориснички интерфејс је подељен у табове, где сваки таб представља појединачну метрику која се прикупља. 
Сваки таб се посебно имплементира са својим виџетима и опцијама. На крају, неопходно их је повезати
како би се омогућило њихово смењивање.

#figure(
```rust

pub enum Tab {
    Overview,
    Cpu,
    Memory,
    Processes,
    Network,
    Disk,
    Notifications,
    Settings,
}
impl Tab {
    pub fn next(&self) -> Self {
        match self {
            Tab::Overview => Tab::Cpu,
            Tab::Cpu => Tab::Memory,
            Tab::Memory => Tab::Processes,
            Tab::Processes => Tab::Network,
            Tab::Network => Tab::Disk,
            Tab::Disk => Tab::Notifications,
            Tab::Notifications => Tab::Settings,
            Tab::Settings => Tab::Overview,
        }
    }
    pub fn previous(&self) -> Self {
        match self {
            Tab::Overview => Tab::Settings,
            Tab::Cpu => Tab::Overview,
            Tab::Memory => Tab::Cpu,
            Tab::Processes => Tab::Memory,
            Tab::Network => Tab::Processes,
            Tab::Disk => Tab::Network,
            Tab::Notifications => Tab::Disk,
            Tab::Settings => Tab::Notifications,
        }
    }
    pub fn title(&self) -> &str {
        match self {
            Tab::Overview => "Overview",
            Tab::Cpu => "CPU",
            ...
        }
    }
}


```,
caption: [Дефиниција таба и њихово повезивање] 
)


