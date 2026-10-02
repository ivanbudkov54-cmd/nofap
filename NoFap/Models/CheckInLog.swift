//
//  CheckInLog.swift
//  NoFap
//
//  Экспресс-чекин: энергия, тяга и триггеры за день одним быстрым касанием.
//  Как и весь остальной дневник — только локально, в UserDefaults. Ни
//  Supabase, ни любой другой сервер сюда не подключены: чекин не покидает
//  устройство.
//

import Foundation

enum CheckInTag: String, CaseIterable, Identifiable, Codable {
    case doomscrolling = "Doomscrolling"
    case boredom = "Boredom"
    case stress = "Stress"
    case lateNightBed = "Late Night Bed"
    case loneliness = "Loneliness"
    case randomUrge = "Random Urge"
    case none = "None"

    var id: String { rawValue }

    /// Подпись на экране — на русском, отдельно от `rawValue`, который
    /// уже сохранён в Codable-записях пользователей и менять его нельзя.
    var label: String {
        switch self {
        case .doomscrolling: String(localized: "Думскроллинг")
        case .boredom:        String(localized: "Скука")
        case .stress:         String(localized: "Стресс")
        case .lateNightBed:   String(localized: "Поздно лёг в постель")
        case .loneliness:     String(localized: "Одиночество")
        case .randomUrge:     String(localized: "Тяга без причины")
        case .none:           String(localized: "Не было")
        }
    }

    /// Тот же триггер в словаре SOS-опроса — чтобы аналитика считала
    /// «скуку» из чекина и «скуку» из SOS одним и тем же.
    var trigger: Trigger? {
        switch self {
        case .doomscrolling: .doomscrolling
        case .boredom:       .boredom
        case .stress:        .stress
        case .lateNightBed:  .bed
        case .loneliness:    .loneliness
        case .randomUrge:    .random
        case .none:          nil
        }
    }
}

struct CheckInEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    /// Точный ISO-таймштамп, зафиксированный в момент сохранения — отдельно
    /// от `date`, чтобы формат не зависел от того, как Codable сериализует Date.
    let isoTimestamp: String
    /// nil — отметка без Premium: уровни не заполнялись, триггеры есть.
    var energyLevel: Int?
    var libidoLevel: Int?
    var triggers: [CheckInTag]
    var note: String

    private static let isoFormatter = ISO8601DateFormatter()

    init(id: UUID = UUID(), date: Date = Date(), energyLevel: Int?, libidoLevel: Int?, triggers: [CheckInTag], note: String) {
        self.id = id
        self.date = date
        self.isoTimestamp = Self.isoFormatter.string(from: date)
        self.energyLevel = energyLevel
        self.libidoLevel = libidoLevel
        self.triggers = triggers
        self.note = note
    }
}

@Observable
final class CheckInManager {

    private enum Key {
        static let entries = "checkInEntries"
    }

    private let defaults: UserDefaults

    /// Новые записи — сверху, как и в остальном дневнике.
    private(set) var entries: [CheckInEntry]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Key.entries),
           let decoded = try? JSONDecoder().decode([CheckInEntry].self, from: data) {
            entries = decoded.sorted { $0.date > $1.date }
        } else {
            entries = []
        }
    }

    func addEntry(energyLevel: Int?, libidoLevel: Int?, triggers: [CheckInTag], note: String, on date: Date = Date()) {
        let entry = CheckInEntry(
            date: date,
            energyLevel: energyLevel,
            libidoLevel: libidoLevel,
            triggers: triggers,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        entries.insert(entry, at: 0)
        persist()
    }

    func deleteEntry(_ entry: CheckInEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func removeAll() {
        entries = []
        defaults.removeObject(forKey: Key.entries)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Key.entries)
    }
}
