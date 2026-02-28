#import "../funkcije.typ": todo
= Архитектура система
<архитектура>

Архитектура је заснована на модуларном приступу који раздваја одговорности и омогућава
лако проширивање и одржавање. Систем је организован у неколико независних модула који
међусобно комуницирају, при чему сваки модул има јасну сврху и одговорност.


== Општа архитектура

Имплементација следи архитектуру засновану на слојевима где се компоненте организују
у хијерархијске нивое према њиховој апстракцији и одговорности. Ова архитектура 
промовише раздвајање одговорности и омогућава да промене у једном слоју имају минималан утицај
на друге слојеве.

У наставку је дат сажет опис свих главних слојева:

*Слој домена* (`oxyd-domain`) — Дефинише основне типове података, _trait_-ове и апстракције које користе остали модули @rust-reference. 

*Слој прикупљача* (`oxyd-collectors`) — Садржи имплементације за прикупљање различитих типова метрика из оперативног 
система. Сваки прикупљач чита податке из `/proc` фајл система @proc-filesystem и трансформише их у доменске типове.

*Слој управљања процесима* (`oxyd-process-manager`) — Пружа функционалност за управљање системским процесима, 
укључујући слање сигнала @posix-signals, терминацију и суспендовање процеса.

*Слој језгра* (`oxyd-core`) — Оркестрира рад свих компоненти, управља животним циклусом прикупљача, и координира 
ток података између различитих делова система.

*Слој корисничког интерфејса* (`oxyd-tui`) — Имплементира терминалски кориснички интерфејс користећи `Ratatui` @ratatui и 
`Crossterm` @crossterm библиотеке. Одговоран је за приказ података и обраду корисничких улаза.

== Модули система

=== oxyd-domain

Модул `oxyd-domain` представља срце система и дефинише све кључне типове података и интерфејсе. Овај модул нема 
зависности према другим модулима, што га чини стабилном основом за целокупан систем.

- Главни типови дефинисани у овом модулу укључују:

  - *SystemMetrics* — Структура која садржи све прикупљене метрике система у једном тренутку (CPU, меморија, мрежа, диск).

#figure(
```rust
pub struct SystemMetrics {
    pub timestamp: DateTime<Utc>,
    pub system_info: SystemInfo,
    pub cpu: CpuMetrics,
    pub memory: MemoryInfo,
    pub disks: Vec<DiskMetrics>,
    pub network: NetworkMetrics,
    pub processes: ProcessMetrics,
}
```,
caption : [Приказ `SystemMetrics` структуре]
)


  - *Process* — Детаљне информације о појединачном процесу (PID, име, CPU употреба, меморија, стање).


#figure(
    ```rust
              pub struct Process {
                  pub pid: u32,
                  pub ppid: Option<u32>,
                  pub name: String,
                  pub command: String,
                  pub arguments: Vec<String>,
                  pub executable_path: Option<String>,
                  pub working_dir: Option<String>,
                  pub state: ProcessState,
                  pub user: String,
                  pub group: String,
                  pub priority: i32,
                  pub nice: i32,
                  pub threads: u32,
                  pub start_time: DateTime<Utc>,
                  pub cpu_usage_percent: f64,
                  pub memory_usage_bytes: u64,
                  pub memory_usage_percent: f64,
                  pub virtual_memory_bytes: u64,
                  pub disk_write_bytes: u64,
                  pub disk_read_bytes: u64,
                  pub open_files: u32,
                  pub open_connections: u32,
              }
```,
caption : [Приказ `Process` структуре]
)
  - *CpuMetrics* — Метрике CPU-а укључујући укупну искоришћеност, искоришћеност по језгрима, и фреквенције.

  #figure(
    ```rust
pub struct CpuMetrics {
    pub overall_usage_percent: f32,
    pub cores: Vec<CpuCore>,
    pub load_average: LoadAverage,
    pub context_switches: u64,
    pub interrupts: u64,
}
```,
caption : [Приказ `CpuMetrics` структуре]
)

  - *MemoryInfo* — Информације о RAM и Swap меморији (укупна, коришћена, доступна, кеширана).

#figure(
```rust
pub struct MemoryInfo {
  pub total_bytes: u64,
  pub used_bytes: u64,
  pub free_bytes: u64,
  pub available_bytes: u64,
  pub cached_bytes: u64,
  pub buffers_bytes: u64,
  pub swap_total_bytes: u64,
  pub swap_used_bytes: u64,
  pub swap_free_bytes: u64,
  pub usage_percent: f32,
  pub swap_usage_percent: f32,
}
```,
caption : [Приказ `MemoryInfo` структуре]
)
  


  - *NetworkMetrics* — Статистика мрежних интерфејса (пренети и примљени бајтови, пакети, грешке).
#figure(
```rust
                  pub struct NetworkMetrics {
                    pub interfaces: Vec<NetworkInterface>,
                    pub stats: Vec<NetworkStats>,
                    pub total_bytes_sent: u64,
                    pub total_bytes_received: u64,
                    pub active_connections: Vec<NetworkConnection>,
                  }
```,
caption : [Приказ `NetworkMetrics` структуре]
)
  

  - *DiskMetrics* — Метрике дисковних уређаја (искоришћеност простора, I/O операције).
#figure(
```rust
pub struct DiskMetrics {
    pub info: DiskInfo,
    pub io_stats: DiskIoStats,
}
```,
    caption : [Приказ `DiskMetrics` структуре]
  )

- Поред структура података, модул дефинише и trait-ове @rust-book:

  - *Collector* - Trait који служи за постављање основних метода колектора.



#figure(
  ```rust
  #[async_trait]
  pub trait Collector: Send + Sync {
      // Јединствени идентификатор за колектор
      fn id(&self) -> &str;
      
      // Прикупља метрике система
      async fn collect(&self) -> Result<SystemMetrics, CollectorError>;
      
      // Провера да ли је колектор доступан на овом систему
      fn is_available(&self) -> bool;
      
      // Дефинише интервал очитавања метрика за колектор
      fn interval_ms(&self) -> u64 {
          1000
      }
  }
  ```,
  caption: [Приказ `Collector` `trait`-а из oxyd-domain модула]
)


  - *ProcessManager* - Trait који служи за постављање основних метода менаџера процеса.
#figure(
```rust


    #[async_trait]
    pub trait ProcessManager: Send + Sync {
    // Приказује све активне процесе.
    async fn list_processes(&self) ->
    Result<Vec<u32>, ProcessError>;

    // Проналази детаљне информације о једном процесу
    // на основу идентификатора.
    async fn get_process(&self, pid: u32) ->
    Result<Process, ProcessError>;

    // Шаље сигнал за насилан крај процеса.
    async fn kill_process(&self, pid: u32) ->
    Result<Process, ProcessError>;

    // Шаље сигнал прослеђен као параметар процесу.
    async fn send_signal(&self, pid:u32, signal: ProcessSignal) ->
    Result<ProcessActionResult, ProcessError>;

    // Поставља приоритет процеса.
    async fn send_priority(&self, pid: u32, priority: i32) ->
    Result<ProcessActionResult, ProcessError>;

    // Суспендује процес.
    async fn suspend_process(&self, pid: u32) ->
    Result<ProcessActionResult, ProcessError>;

    // Наставља процес.
    async fn continue_process(&self, pid: u32) ->
    Result<ProcessActionResult, ProcessError>;
}
```,
  caption: [Приказ `ProcessManager` `trait`-а из oxyd-domain модула]
)


=== oxyd-collectors

Модул `oxyd-collectors` садржи имплементације прикупљача за различите типове метрика. Сваки прикупљач имплементира 
`Collector` trait и специјализован је за читање одређеног типа података из `/proc` фајл система @proc-filesystem.

*CpuCollector* — Чита `/proc/stat` фајл и рашчлањује линије које садрже CPU статистике. Прати време проведено у 
различитим стањима (user, system, idle, iowait) за сваки CPU и израчунава проценат искоришћености.

*MemoryCollector* — Чита `/proc/meminfo` фајл који садржи детаљне информације о меморији. Парсира вредности као што 
су MemTotal, MemFree, MemAvailable, Buffers, Cached, SwapTotal, SwapFree.

*NetworkCollector* — Чита `/proc/net/dev` који садржи статистику за све мрежне интерфејсе. За сваки интерфејс прати 
примљене и послате бајтове, пакете, грешке и одбачене пакете.

*DiskCollector* — Комбинује информације из `/proc/diskstats` за I/O статистику и `df` команду за искоришћеност 
простора на монтираним фајл системима.

*ProcessCollector* — Итерира кроз `/proc/[pid]/` директоријуме за све процесе и чита информације из фајлова као што 
су `stat`, `status`, `cmdline`, `io` @proc-filesystem.

Сви прикупљачи раде асинхроно користећи Tokio runtime @tokio, што омогућава паралелно прикупљање различитих метрика 
без блокирања.

#figure(
```rust

#[async_trait]
impl Collector for CpuCollector {
    fn id(&self) -> &str {
        "cpu"
    }

    async fn collect(&self) -> Result<SystemMetrics, CollectorError> {
        let current_stats = self.read_cpu_stats().await?;
        let load_avg = self.read_load_average().await?;

        let mut previous_lock = self.previous_stats.lock().await;
        ...
      }


    fn is_available(&self) -> bool {
        std::path::Path::new("/proc/stat").exists()
    }
}
```,
  caption: [Део кода једног од колектора]
)

=== oxyd-process-manager

Модул `oxyd-process-manager` имплементира функционалност за управљање процесима @posix-signals.

Главне функције овог модула су:

- Слање SIGTERM сигнала за љубазно гашење процеса
- Слање SIGKILL сигнала за насилно гашење
- Слање SIGSTOP сигнала за суспендовање процеса
- Слање SIGCONT сигнала за наставак суспендованог процеса
- Провера постојања и валидности процеса


#figure(
```rust

#[async_trait]
impl ProcessManager for LinuxProcessManager {
    async fn list_processes(&self) -> Result<Vec<u32>, ProcessError> {
        let mut pids = Vec::new();
        let mut entries = fs::read_dir("/proc").await
            .map_err(|e| ProcessError::ListFailed(format!("Failed to
            read /proc: {}", e)))?;

        while let Some(entry) = entries.next_entry().await
            .map_err(|e| ProcessError::ListFailed(format!("Failed to
            read entry: {}", e)))? {
            let file_name = entry.file_name();
            let file_name_str = file_name.to_string_lossy();

            if let Ok(pid) = file_name_str.parse::<u32>() {
                let stat_path = format!("/proc/{}/stat", pid);
                if Path::new(&stat_path).exists() {
                    pids.push(pid);
                }
            }
        }

        Ok(pids)
    }
```,
  caption: [Приказ функције за добављање процеса]
)

=== oxyd-core

Модул `oxyd-core` представља централну компоненту која оркестрира рад целокупног система. Овај модул је одговоран за:

- Иницијализацију свих прикупљача
- Периодично покретање прикупљања метрика
- Агрегацију података из различитих извора
- Пружање API-ја за остале компоненте

*Engine* — Главна структура која управља свим прикупљачима. Периодично позива `collect()` методу на сваком 
прикупљачу и складишти резултате. Користи `broadcast` канал из Tokio библиотеке @tokio за дистрибуцију метрика.


#figure(
```rust

pub struct Engine {
    collectors: Arc<RwLock<Vec<Box<dyn Collector>>>>,
    process_manager: Arc<dyn ProcessManager>,
    metrics_tx: broadcast::Sender<SystemMetrics>,
    config: Config,
    running: Arc<RwLock<bool>>,
}
```,
  caption: [Приказ структуре `Engine`]
)

=== oxyd-tui

Модул `oxyd-tui` имплементира терминалски кориснички интерфејс користећи Ratatui @ratatui и Crossterm @crossterm. Архитектура 
је заснована на Flux обрасцу @flux, који користи једносмеран ток података и предвидљиво управљање стањем апликације.

==== Flux архитектура

Flux @flux је образац креиран од стране Facebook-а за развој корисничких интерфејса. 
Основна идеја је једносмеран ток података (енг. _unidirectional data flow_) где акције (енг. _actions_) 
покрећу промене стања, а стање се затим одражава у приказу.

`oxyd-tui` модул имплементира следеће Flux компоненте:

*Actions* — Представљају све могуће догађаје и намере у апликацији. Ово укључује корисничке интеракције (притиске 
тастера, кликове миша), системске догађаје (ажурирања метрика, промене величине терминала), и интерне догађаје 
(таймаути, грешке).

*Dispatcher* — Централна тачка за рутирање акција. Прима акције из различитих извора и прослеђује их одговарајућим 
handler-има који ажурирају стање.

*Store* — Чува комплетно стање апликације. У Oxyd-у, ово је `AppState` структура која садржи тренутни таб, метрике, 
селекције, филтере и сва друга релевантна стања.

*View* — Рендерује кориснички интерфејс на основу тренутног стања. Користи Ratatui виџете @ratatui-widgets за приказ података и 
не мења стање директно.

==== Предности Flux архитектуре

Коришћење Flux обрасца @flux у `oxyd-tui` модулу пружа неколико кључних предности:

*Предвидљиво стање* — Једносмеран ток података чини промењиво стање лакшим за праћење и дебаговање. Свака промена 
стања се дешава кроз акције које се могу лако логовати и пратити.

*Раздвојене одговорности* — View слој је потпуно одвојен од логике управљања стањем. View само рендерује и генерише 
акције, док Dispatcher брине о ажурирању стања.

*Тестабилност* — Свака компонента се може независно тестирати. Dispatcher логика се тестира слањем акција и 
проверавањем резултујућег стања, док се View тестира провером да исправно рендерује дато стање.

*Проширивост* — Додавање нових функција захтева само дефинисање нових акција и њихових handler-а, без промене 
постојећег кода.


== Ток података

Ток података кроз Oxyd систем прати јасан образац од прикупљања до приказа:

1. *Прикупљање* — Engine периодично активира све регистроване колекторе. 
   Сваки колектор асинхроно чита свој извор података из `/proc` фајл система @proc-filesystem.

2. *Агрегација* — Подаци из свих прикупљача се комбинују у јединствену `SystemMetrics` структуру која представља 
   комплетан приказ стања система у датом тренутку.

3. *Дистрибуција* — Engine емитује нове метрике преко broadcast канала @tokio на који су претплаћене компоненте 
   корисничког интерфејса.

4. *Приказ* — TUI компонента прима ажурирање, ажурира своје интерно стање, и рендерује нови приказ @ratatui.

Овај приступ обезбеђује да кориснички интерфејс остаје ажуран јер прикупљање података ради у позадини и не блокира 
нит корисничког интерфејса. Коришћење `broadcast` канала омогућава да више компоненти UI-ја могу независно реаговати на иста ажурирања.

== Обрасци дизајна

У имплементацији Oxyd-а коришћено је неколико добро познатих образаца дизајна:

*Observer* — Broadcast канали @tokio имплементирају observer образац где TUI компоненте могу да се претплате на 
ажурирања метрика.

*Command* — Обрада корисничких улаза користи command образац где сваки input производи `Action` enum који 
се затим извршава.

*Dependency Injection* — Сви модули примају своје зависности кроз конструкторе или методе, што олакшава тестирање 
и флексибилност.

== Синхронизација

За синхронизацију се користе Tokio примитиви @tokio @tokio-tutorial:

*Mutex и RwLock* — За заштиту дељених структура података. 

*Channels* — За комуникацију између задатака. 

*Arc* — За дељење података између задатака. 

Раст-ов систем власништва и позајмљивања @rust-book гарантује да не може доћи до data race-ова @jung2020rust, што чини конкурентни код 
безбедним по дизајну.
