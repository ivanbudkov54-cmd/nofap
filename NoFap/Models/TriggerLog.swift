//
//  TriggerLog.swift
//  NoFap
//
//  Что предшествовало тяге — короткий опрос после SOS. Не для чувства
//  вины, а чтобы со временем стало видно закономерность: если триггер
//  повторяется, с ним можно работать заранее, а не только в момент тяги.
//

import Foundation

enum Trigger: String, CaseIterable, Identifiable, Codable {
    case doomscrolling
    case boredom
    case stress
    case bed
    case loneliness
    case random

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .doomscrolling: "📱"
        case .boredom:       "🥱"
        case .stress:        "🧠"
        case .bed:           "🛏️"
        case .loneliness:    "👤"
        case .random:        "⚡"
        }
    }

    var title: String {
        switch self {
        case .doomscrolling: String(localized: "Думскроллинг / соцсети")
        case .boredom:       String(localized: "Скука / прокрастинация")
        case .stress:        String(localized: "Стресс / тревога")
        case .bed:           String(localized: "Кровать перед сном")
        case .loneliness:    String(localized: "Одиночество / апатия")
        case .random:        String(localized: "Внезапный импульс")
        }
    }

    var subtitle: String {
        switch self {
        case .doomscrolling: String(localized: "TikTok, Instagram, лента с триггерными видео")
        case .boredom:       String(localized: "Скука, нежелание делать сложное дело или учёбу")
        case .stress:        String(localized: "Нервы, конфликт, тяжёлый день, попытка сбежать от реальности")
        case .bed:           String(localized: "Лежу в кровати перед сном или утром, не могу уснуть")
        case .loneliness:    String(localized: "Чувство одиночества, апатия, «всё надоело»")
        case .random:        String(localized: "Внезапный сильный телесный импульс без явной причины")
        }
    }
}

struct TriggerEntry: Codable {
    let trigger: Trigger
    let date: Date
}

/// Копится локально в UserDefaults — тот же принцип, что и у остальных данных
/// приложения: ничего не покидает устройство.
enum TriggerLog {

    private static let key = "triggerLog"

    static func record(_ trigger: Trigger, defaults: UserDefaults = .standard) {
        var entries = load(defaults: defaults)
        entries.append(TriggerEntry(trigger: trigger, date: Date()))
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    static func removeAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func entries(defaults: UserDefaults = .standard) -> [TriggerEntry] {
        load(defaults: defaults)
    }

    private static func load(defaults: UserDefaults) -> [TriggerEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TriggerEntry].self, from: data) else { return [] }
        return decoded
    }
}
