#let format_strane = "iso-b5"         // могуће вредности: iso-b5, a4
#let naslov = "Дизајн и имплементација мониторинг система на програмском језику Раст"
#let autor = "Душан Лечић"

// На енглеском
#let naslov_eng = "Design and Implementation of a Monitoring System in the Rust Programming Language"
#let autor_eng = "Dušan Lečić"

#let indeks = "SV 80/2021"

// Име и презиме ментора
#let mentor = "Игор Дејановић"
// Звање: редовни професор, ванредни професор, доцент
#let mentor_zvanje = "редовни професор"

// Скинути коментаре са одговарајућих линија
#let studijski_program = "Софтверско инжењерство и информационе технологије"
//#let studijski_program = "Рачунарство и аутоматика"
//#let stepen = "Мастер академске студије"
#let stepen = "Основне академске студије"

#let godina = [#datetime.today().year()]

#let kljucne_reci = "Мониторинг система, Модуларан дизајн, Оперативни системи, Руст, Терминал, Flux архитектура, Ratatui"
#let apstrakt = [
     Овај рад представља развој терминалног алата за мониторинг система у програмском језику Раст. 
     Циљ је израда брзог, ефикасног и поузданог решења које омогућава приказ искоришћености ресурса и надзор над активним процесима. 
     Архитектура апликације заснива се на модуларном дизајну и Flux архитектонском обрасцу, док је кориснички интерфејс реализован 
     у терминалу помоћу Ratatui библиотеке.
]
// На енглеском
#let kljucne_reci_eng = "System monitor, Clean architecture, Operating systems, Rust, Terminal, Flux architecture, Ratatui"
#let apstrakt_eng = [
     This thesis presents the development of a terminal-based system monitoring tool written in the Rust programming language. 
     The goal is to create a fast, efficient, and reliable solution for visualizing system resource usage and monitoring active processes. 
     The application architecture follows a modular design and the Flux architectural pattern, while the terminal user interface 
     is implemented using the Ratatui library.
]
// TODO: Текст задатка добијате од ментора. Заменити доле #lorem(100) са текстом задатка.
#let zadatak = [

    Истражити област алата за мониторинг система. Дизајнирати и имплементирати
    брзо, ефикасно и поуздано решењe које омогућава приказ искоришћености
    ресурса и надзор над активним процесима. У имплементацији користити
    програмски језик Раст.

    При изради користити препоручену праксу из области софтверског инжењерства.
    Детаљно документовати решење.
]

// TODO: Датум одбране и чланове комисије добијате од ментора
#let datum_odbrane = "28.04.2026"

#let komisija_predsednik = "Мирослав Зарић"
#let komisija_predsednik_zvanje = "редовни професор"
#let komisija_clan = "Гордана Милосављевић"
#let komisija_clan_zvanje = "редовни професор"

// На енглеском уписати чланове на латиници
#let komisija_predsednik_eng = "Miroslav Zarić"
#let komisija_clan_eng = "Gordana Milosavljević"
#let mentor_eng = "Igor Dejanović"


// Ово даље углавном не треба мењати.

#let zvanje_eng = (
     "редовни професор": "full professor",
     "ванредни професор": "assoc. professor",
     "доцент": "asist. professor",
)
#let komisija_predsednik_zvanje_eng = zvanje_eng.at(komisija_predsednik_zvanje)
#let komisija_clan_zvanje_eng = zvanje_eng.at(komisija_clan_zvanje)
#let mentor_zvanje_eng = zvanje_eng.at(mentor_zvanje)


#let vrsta_rada = if stepen == "Мастер академске студије" {
    "Дипломски - мастер рад"
} else {
    "Дипломски - бечелор рад"
}

#let oblast = "Електротехничко и рачунарско инжењерство"
#let oblast_eng = "Electrical and Computer Engineering"
#let disciplina = "Примењене рачунарске науке и информатика"
#let disciplina_eng = "Applied computer science and informatics"

#import "funkcije.typ": *
// Поглавља/страна/цитата/табела/слика/графика/прилога
#let fizicki_opis = physical()
