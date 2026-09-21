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
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func today() -> String {
        string(from: Date())
    }
}
