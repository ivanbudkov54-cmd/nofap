//
//  DayKey.swift
//  NoFap
//
//  Ключ дня "yyyy-MM-dd" — общий для локальной истории и для того, что
//  видит напарник. Вынесен из StreakManager намеренно: если бы каждая
//  сторона форматировала дату сама, форматы со временем разошлись бы,
//  и «держится сегодня» начало бы врать.
//

import Foundation

enum DayKey {

    /// Григорианский календарь и локальная зона: день считается по часам
    /// того, кто смотрит, а не по UTC.
    ///
    /// Зона именно `autoupdatingCurrent`: форматтер живёт всё время работы
    /// приложения, а `.current` заморозил бы зону на момент первого обращения.
    /// После перелёта запись дня и проверка «это сегодня?» разошлись бы.
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .autoupdatingCurrent
        return f
    }()

    /// Календарь для недельных расчётов: неделя с понедельника независимо от
    /// региона устройства. Один экземпляр на всё приложение — раньше он
    /// пересобирался на каждое обращение внутри отрисовки.
    static let isoCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .autoupdatingCurrent
        return cal
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// Сокращения дней недели с понедельника, на языке системы. Раньше это
    /// был массив «ПН, ВТ, …» прямо в коде — по-русски, и в двух местах.
    static var weekdaySymbolsMondayFirst: [String] {
        var calendar = isoCalendar
        calendar.locale = .autoupdatingCurrent
        // `shortWeekdaySymbols` всегда начинается с воскресенья, независимо
        // от `firstWeekday`, — поэтому переставляем вручную.
        let symbols = calendar.shortWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    static func today() -> String {
        string(from: Date())
    }
}
