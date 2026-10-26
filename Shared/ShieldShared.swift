//
//  ShieldShared.swift
//  NoFap
//
//  Общее для приложения, двух расширений Экранного времени и виджета.
//  Расширения живут в отдельных процессах и видят только App Group:
//  приложение кладёт туда стрик, цель и цитату из «Договора», экран
//  блокировки и виджет их показывают, а кнопки на щите считают, сколько
//  раз он остановил человека.
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
        static let goalDays = "widget.goalDays"
        static let lastCheckin = "widget.lastCheckin"
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var streakDays: Int { defaults.integer(forKey: Key.streakDays) }
    static var quote: String? { defaults.string(forKey: Key.quote) }
    static var stops: Int { defaults.integer(forKey: Key.stops) }
    static var goalDays: Int { max(defaults.integer(forKey: Key.goalDays), 1) }
    static var lastCheckin: Date? { defaults.object(forKey: Key.lastCheckin) as? Date }

    static func recordStop() {
        defaults.set(stops + 1, forKey: Key.stops)
    }
}
