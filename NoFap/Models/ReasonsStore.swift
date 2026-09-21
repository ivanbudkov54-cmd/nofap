//
//  ReasonsStore.swift
//  NoFap
//
//  Личные причины: какие выбраны и какие человек добавил сам. Вынесено из
//  WhyView по той же причине, что и SurveyManager из онбординга — во вью
//  запись шла тремя разными путями, без единой точки сохранения.
//

import Foundation
import os

@Observable
final class ReasonsStore {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "reasons")

    private enum Key {
        static let custom = "customReasons"
        static let selected = "selectedReasons"
    }

    /// Своя причина — не просто строка: два человека могут вписать одно и то
    /// же слово, а до этого выбор хранился по тексту, и такие причины
    /// склеивались в одну.
    struct Custom: Codable, Identifiable, Hashable {
        let id: UUID
        var text: String

        init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    private(set) var custom: [Custom]
    private(set) var selected: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = Set(defaults.stringArray(forKey: Key.selected) ?? [])

        if let data = defaults.data(forKey: Key.custom),
           let decoded = try? JSONDecoder().decode([Custom].self, from: data) {
            custom = decoded
        } else {
            // Раньше причины лежали простым массивом строк — переносим их,
            // чтобы у людей не пропало то, что они уже вписали.
            custom = (defaults.stringArray(forKey: Key.custom) ?? []).map { Custom(text: $0) }
            persistCustom()
        }
    }

    func isSelected(_ key: String) -> Bool {
        selected.contains(key)
    }

    func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
        defaults.set(Array(selected), forKey: Key.selected)
    }

    func add(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        custom.append(Custom(text: text))
        persistCustom()
    }

    func remove(_ reason: Custom) {
        custom.removeAll { $0.id == reason.id }
        selected.remove(reason.key)
        defaults.set(Array(selected), forKey: Key.selected)
        persistCustom()
    }

    private func persistCustom() {
        do {
            defaults.set(try JSONEncoder().encode(custom), forKey: Key.custom)
        } catch {
            Self.log.error("Не удалось сохранить причины: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension ReasonsStore.Custom {
    /// Ключ выбора — идентификатор, а не текст: одинаковые причины остаются
    /// разными.
    var key: String { id.uuidString }
}
