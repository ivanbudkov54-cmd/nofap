//
//  JournalManager.swift
//  NoFap
//
//  Личный дневник: свободные заметки о дне, без структуры и оценок.
//  Хранится локально в UserDefaults; если сервер подключён, CloudSync
//  копирует записи в journal_entries — видны они только самому человеку.
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

    /// Растёт при любом изменении — сигнал для CloudSync.
    private(set) var revision = 0

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

    /// Итог сверки с сервером: записи с других устройств (или сохранённые до
    /// переустановки) добавляются, удалённые там — убираются.
    func applyRemote(added: [JournalEntry], removed: Set<UUID>) {
        guard !added.isEmpty || !removed.isEmpty else { return }
        let known = Set(entries.map(\.id))
        entries.removeAll { removed.contains($0.id) }
        entries += added.filter { !known.contains($0.id) }
        entries.sort { $0.date > $1.date }
        persist()
    }

    private func persist() {
        revision += 1
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Key.entries)
    }
}
