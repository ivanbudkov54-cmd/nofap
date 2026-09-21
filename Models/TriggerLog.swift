//
//  TriggerLog.swift
//  NoFap
//
//  Что предшествовало срыву тяги — короткий опрос после SOS. Не для чувства
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
        case .doomscrolling: "Doomscrolling / Social Media"
        case .boredom:       "Boredom / Procrastination"
        case .stress:        "Stress / Anxiety"
        case .bed:           "Bed & Insomnia"
        case .loneliness:    "Loneliness / Flatline"
        case .random:        "Random Physical Urge"
        }
    }

    var subtitle: String {
        switch self {
        case .doomscrolling: "TikTok, Instagram, лента с триггерными видео"
        case .boredom:       "Скука, нежелание делать сложное дело или учёбу"
        case .stress:        "Нервы, конфликт, тяжёлый день, попытка сбежать от реальности"
        case .bed:           "Лежу в кровати перед сном или утром, не могу уснуть"
        case .loneliness:    "Чувство одиночества, апатия, «всё надоело»"
        case .random:        "Внезапный сильный телесный импульс без явной причины"
        }
    }
}

private struct TriggerEntry: Codable {
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

    private static func load(defaults: UserDefaults) -> [TriggerEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TriggerEntry].self, from: data) else { return [] }
        return decoded
    }
}
