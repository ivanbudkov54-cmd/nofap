//
//  ShieldShared.swift
//  NoFap
//
//  Общее для приложения и двух расширений Экранного времени. Расширения
//  живут в отдельных процессах и видят только App Group: приложение кладёт
//  туда стрик и цитату из «Договора», экран блокировки их показывает, а
//  кнопки на нём считают, сколько раз щит остановил человека.
//

import Foundation

nonisolated enum ShieldShared {

    static let appGroup = "group.Albert.lvan.NoFap"

    /// Ссылка, по которой приложение открывает SOS.
    static let sosURL = URL(string: "nofap://sos")!

    /// userInfo уведомления, которое ставит экран блокировки.
    static let sosUserInfoKey = "open"
    static let sosUserInfoValue = "sos"

    enum Key {
        static let streakDays = "shield.streakDays"
        static let quote = "shield.quote"
        static let stops = "shield.stops"
        static let selection = "shield.selection"
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var streakDays: Int { defaults.integer(forKey: Key.streakDays) }
    static var quote: String? { defaults.string(forKey: Key.quote) }
    static var stops: Int { defaults.integer(forKey: Key.stops) }

    static func recordStop() {
        defaults.set(stops + 1, forKey: Key.stops)
    }
}
