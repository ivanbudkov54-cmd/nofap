//
//  TriggerInsights.swift
//  NoFap
//
//  Аналитика триггеров из двух источников: опроса после SOS и тегов
//  экспресс-чекина. Считается на телефоне, никуда не отправляется.
//
//  Время суток берётся только из SOS: там записан момент тяги. Чекин —
//  итог дня, записанный когда угодно, и его время о тяге ничего не говорит.
//

import Foundation

struct TriggerInsights {

    enum DayPart: Int, CaseIterable {
        case morning, afternoon, evening, night

        init(hour: Int) {
            switch hour {
            case 5..<12:  self = .morning
            case 12..<17: self = .afternoon
            case 17..<22: self = .evening
            default:      self = .night
            }
        }

        var label: String {
            switch self {
            case .morning:   String(localized: "Утро")
            case .afternoon: String(localized: "День")
            case .evening:   String(localized: "Вечер")
            case .night:     String(localized: "Ночь")
            }
        }

        /// «Чаще всего тянет …»
        var phrase: String {
            switch self {
            case .morning:   String(localized: "по утрам")
            case .afternoon: String(localized: "днём")
            case .evening:   String(localized: "по вечерам")
            case .night:     String(localized: "ночью")
            }
        }
    }

    struct Count<Key>: Identifiable where Key: Hashable {
        let key: Key
        let count: Int
        var id: Key { key }
    }

    /// Сколько раз отмечен каждый триггер, по убыванию. Нулевых нет.
    let triggers: [Count<Trigger>]
    /// Тяга по времени суток — все четыре части, в порядке суток.
    let dayParts: [Count<DayPart>]
    /// По дням недели — понедельник первым, все семь.
    let weekdays: [Count<Int>]

    let totalMarks: Int
    let sosMoments: Int

    /// Меньше — картина случайная, выводы делать рано.
    static let minimumMarks = 3

    var hasEnoughData: Bool { totalMarks >= Self.minimumMarks }

    var topTrigger: Trigger? { triggers.first?.key }

    var peakDayPart: DayPart? {
        guard sosMoments > 0 else { return nil }
        return dayParts.max { $0.count < $1.count }?.key
    }

    /// Индекс 0…6 (понедельник…воскресенье), если пик заметен.
    var peakWeekday: Int? {
        guard let best = weekdays.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        // Ничья — не пик: «чаще всего в понедельник» при равенстве врёт.
        return weekdays.filter { $0.count == best.count }.count == 1 ? best.key : nil
    }

    init(sos: [TriggerEntry], checkIns: [CheckInEntry], calendar: Calendar = DayKey.isoCalendar) {
        var byTrigger: [Trigger: Int] = [:]
        var byDayPart: [DayPart: Int] = [:]
        var byWeekday = Array(repeating: 0, count: 7)

        func weekdayIndex(_ date: Date) -> Int {
            // Calendar.weekday: 1 — воскресенье. Сдвигаем к понедельнику.
            (calendar.component(.weekday, from: date) + 5) % 7
        }

        for entry in sos {
            byTrigger[entry.trigger, default: 0] += 1
            byDayPart[DayPart(hour: calendar.component(.hour, from: entry.date)), default: 0] += 1
            byWeekday[weekdayIndex(entry.date)] += 1
        }

        var marks = sos.count
        for entry in checkIns {
            let found = entry.triggers.compactMap(\.trigger)
            guard !found.isEmpty else { continue }
            found.forEach { byTrigger[$0, default: 0] += 1 }
            byWeekday[weekdayIndex(entry.date)] += 1
            marks += found.count
        }

        triggers = byTrigger
            .map { Count(key: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.key.rawValue < $1.key.rawValue }
        dayParts = DayPart.allCases.map { Count(key: $0, count: byDayPart[$0] ?? 0) }
        weekdays = (0..<7).map { Count(key: $0, count: byWeekday[$0]) }
        totalMarks = marks
        sosMoments = sos.count
    }

    static func weekdayShort(_ index: Int) -> String {
        [String(localized: "Пн"), String(localized: "Вт"), String(localized: "Ср"),
         String(localized: "Чт"), String(localized: "Пт"), String(localized: "Сб"),
         String(localized: "Вс")][index]
    }

    /// «в понедельник», «во вторник» — для фразы-вывода.
    static func weekdayPhrase(_ index: Int) -> String {
        [String(localized: "в понедельник"), String(localized: "во вторник"),
         String(localized: "в среду"), String(localized: "в четверг"),
         String(localized: "в пятницу"), String(localized: "в субботу"),
         String(localized: "в воскресенье")][index]
    }
}
