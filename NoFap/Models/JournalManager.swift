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
    /// Подпись записи-разбора после щита стрика. Та же строка, что у друга
    /// в journal_entries.prompt_text, — записи узнаются на любом устройстве.
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

    func removeAll() {
        entries = []
        defaults.removeObject(forKey: Key.entries)
    }

    private func persist() {
        revision += 1
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Key.entries)
    }
}
