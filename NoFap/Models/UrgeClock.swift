//
//  UrgeClock.swift
//  NoFap
//
//  Настоящий опасный час по моментам тяги — для умного напоминания.
//  Анкета в онбординге говорит, когда человеку кажется, что тянет; здесь —
//  когда тянуло на самом деле: SOS и отмеченные срывы.
//

import Foundation

/// Моменты срывов с точным временем. StreakManager хранит только день
/// («сорвался 12-го»), а для часа нужно и время.
enum RelapseLog {

    private static let key = "relapseMoments"

    static func record(at date: Date = Date(), defaults: UserDefaults = .standard) {
        var all = dates(defaults: defaults)
        all.append(date)
        defaults.set(all.map(\.timeIntervalSince1970), forKey: key)
    }

    static func removeAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func dates(defaults: UserDefaults = .standard) -> [Date] {
        (defaults.array(forKey: key) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
    }
}

enum UrgeClock {

    /// Меньше — не закономерность, а совпадение.
    static let minimumMoments = 3

    /// Старые привычки меняются: смотрим только на последние два месяца.
    static let lookback: TimeInterval = 60 * 24 * 3600

    /// Час (0–23), с которого начинается самое плотное двухчасовое окно
    /// тяги, или nil, если данных мало. Окно, а не один час: тяга в 21:50
    /// и в 22:10 — это один вечер, а не два разных часа.
    static func peakHour(sos: [TriggerEntry],
                         relapses: [Date],
                         now: Date = Date(),
                         calendar: Calendar = .autoupdatingCurrent) -> Int? {
        let since = now.addingTimeInterval(-lookback)
        let moments = (sos.map(\.date) + relapses).filter { $0 >= since && $0 <= now }
        guard moments.count >= minimumMoments else { return nil }

        var byHour = Array(repeating: 0, count: 24)
        moments.forEach { byHour[calendar.component(.hour, from: $0)] += 1 }

        let scores = (0..<24).map { byHour[$0] + byHour[($0 + 1) % 24] }
        return scores.indices.max { scores[$0] < scores[$1] }
    }
}
