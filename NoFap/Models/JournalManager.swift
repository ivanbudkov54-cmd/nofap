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
    static let shieldBadge = "Разбор срыва (Щит стрика)"
    static let manifestBadge = "📌 Моя точка А: Манифест старта"

    var isManifest: Bool { promptQuestion == Self.manifestBadge }
    let id: UUID
    let date: Date
    var text: String
    /// Вопрос-подсказка, на который отвечала эта запись — nil у записей
    /// без подсказки (например, старых, сохранённых до этой функции).
    var promptQuestion: String?
    var moodScore: Int?
    var urgeScore: Int?
    /// nil у старых записей без этого поля — для них бейджа щита нет.
    var isShieldReview: Bool?

    init(id: UUID = UUID(), date: Date = Date(), text: String, promptQuestion: String? = nil, moodScore: Int? = nil, urgeScore: Int? = nil, isShieldReview: Bool? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.promptQuestion = promptQuestion
        self.moodScore = moodScore
        self.urgeScore = urgeScore
        self.isShieldReview = isShieldReview
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

    func addManifest(_ text: String, on date: Date = Date()) {
        addEntry(text, promptQuestion: JournalEntry.manifestBadge, on: date)
    }

    func addEntry(_ text: String, promptQuestion: String? = nil, moodScore: Int? = nil, urgeScore: Int? = nil, isShieldReview: Bool? = nil, on date: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || moodScore != nil || urgeScore != nil else { return }
        entries.insert(
            JournalEntry(date: date, text: trimmed, promptQuestion: promptQuestion, moodScore: moodScore, urgeScore: urgeScore, isShieldReview: isShieldReview),
            at: 0
        )
        persist()
    }

    /// Лента после select из journal_entries. Локальный кэш заменяется
    /// серверным списком, чтобы не копить две копии одной записи.
    func replaceAll(_ incoming: [JournalEntry]) {
        entries = incoming.sorted { $0.date > $1.date }
        persist()
    }

    func deleteEntry(_ entry: JournalEntry) {
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
