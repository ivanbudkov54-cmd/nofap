//
//  JournalManager.swift
//  NoFap
//
//  Личный дневник: свободные заметки о дне, без структуры и оценок.
//  Хранится локально в UserDefaults — тот же принцип, что и у остальных
//  данных приложения: ничего не покидает устройство.
//

import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var text: String
    /// Вопрос-подсказка, на который отвечала эта запись — nil у записей
    /// без подсказки (например, старых, сохранённых до этой функции).
    var promptQuestion: String?

    init(id: UUID = UUID(), date: Date = Date(), text: String, promptQuestion: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.promptQuestion = promptQuestion
    }
}

@Observable
final class JournalManager {

    private enum Key {
        static let entries = "journalEntries"
    }

    private let defaults: UserDefaults

    /// Новые записи — сверху, как в любом дневнике.
    private(set) var entries: [JournalEntry]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Key.entries),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded.sorted { $0.date > $1.date }
        } else {
            entries = []
        }
    }

    func addEntry(_ text: String, promptQuestion: String? = nil, on date: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.insert(JournalEntry(date: date, text: trimmed, promptQuestion: promptQuestion), at: 0)
        persist()
    }

    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Key.entries)
    }
}
