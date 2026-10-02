//
//  CloudSync.swift
//  NoFap
//
//  Личные данные на сервере (таблицы из supabase/01_core.sql): стрик в
//  profiles, записи дневника, моменты срывов. Тот же анонимный вход, что
//  у напарника и сквада, — SupabaseSession.shared, один пользователь.
//
//  Телефон остаётся главным: экран всегда работает от локальных данных,
//  сеть только копирует их и молча отступает без ключей или интернета.
//

import Foundation
import os

/// Статья из knowledge_articles — их публикует друг прямо в Supabase.
struct KnowledgeArticle: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let tabType: String
    let title: String
    let description: String?
    let content: String?
    let orderIndex: Int
}

@MainActor
@Observable
final class CloudSync {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "cloud")

    private let db = SupabaseClient(session: .shared)
    private let defaults: UserDefaults

    private enum Key {
        /// Записи дневника, которые точно есть и тут, и на сервере. Нужны,
        /// чтобы отличить «удалили здесь» от «добавили на другом устройстве».
        static let syncedJournal = "cloud.syncedJournalIDs"
        /// Последний срыв, уже отправленный в relapses.
        static let relapsesUploadedUntil = "cloud.relapsesUploadedUntil"
        /// Статьи с сервера — чтобы вкладки не пустели без сети.
        static let articles = "knowledgeArticlesCache"
    }

    private var isSyncingJournal = false

    /// Статьи для вкладок «Мой путь», «Симулятор тяги», «Глубже».
    private(set) var articles: [KnowledgeArticle] = []
    /// Пока идёт сохранение заметки — экран дневника показывает спиннер.
    private(set) var isSavingJournal = false
    /// Сообщение для пользователя после неудачного действия. Тихая фоновая
    /// синхронизация его не трогает: без сети всё и так лежит на телефоне.
    var notice: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Key.articles),
           let cached = try? JSONDecoder().decode([KnowledgeArticle].self, from: data) {
            articles = cached
        }
    }

    // MARK: - Статьи

    func articles(tab: String) -> [KnowledgeArticle] {
        articles.filter { $0.tabType == tab }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Статьи читаются и без входа — политика открыта для роли anon, но
    /// общий клиент всё равно ходит с токеном, так проще.
    func refreshArticles() async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            let remote: [KnowledgeArticle] = try await db.select(
                "knowledge_articles", [("order", "order_index.asc")],
                columns: "id,tab_type,title,description,content,order_index")
            articles = remote
            if let data = try? JSONEncoder().encode(remote) {
                defaults.set(data, forKey: Key.articles)
            }
        } catch {
            Self.log.error("articles refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Стрик и срывы

    /// Число дней, рекорд, начало стрика и новые срывы. Вызывается при
    /// каждом изменении стрика и на старте.
    func push(streak: StreakManager) async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            let me = try await SupabaseSession.shared.userID()
            try await uploadNewRelapses(me: me)

            let lastRelapse = RelapseLog.dates().max()
            let now = PostgresTime.string(from: Date())
            try await db.insert("profiles", [[
                "id": me,
                "current_streak_days": streak.currentStreak,
                "best_streak_days": streak.bestStreak,
                // Старые имена колонок — их ещё читает схема друга.
                "streak_days": streak.currentStreak,
                "best_streak": streak.bestStreak,
                "streak_start_date": streakStart(streak).map(PostgresTime.string(from:)),
                "last_relapse_at": lastRelapse.map(PostgresTime.string(from:)),
                "last_streak_freeze_date": streak.lastShieldDate.map(PostgresTime.string(from:)),
                "updated_at": now,
            ]], upsert: true)
        } catch {
            Self.log.error("streak push failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Стрик считается по отметкам: последняя чистая отметка — его
    /// последний день, начало — на (дней − 1) раньше.
    private func streakStart(_ streak: StreakManager) -> Date? {
        guard streak.currentStreak > 0, let last = streak.lastCheckinDate else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        return calendar.date(byAdding: .day, value: -(streak.currentStreak - 1),
                             to: calendar.startOfDay(for: last))
    }

    private func uploadNewRelapses(me: String) async throws {
        let uploadedUntil = defaults.object(forKey: Key.relapsesUploadedUntil) as? Date ?? .distantPast
        let fresh = RelapseLog.dates().filter { $0 > uploadedUntil }.sorted()
        guard let newest = fresh.last else { return }
        try await db.insert("relapses", fresh.map {
            ["user_id": me, "relapsed_at": PostgresTime.string(from: $0)]
        })
        defaults.set(newest, forKey: Key.relapsesUploadedUntil)
    }

    // MARK: - Дневник

    private struct JournalRow: Decodable {
        let id: UUID
        let moodScore: Int?
        let urgeScore: Int?
        let promptText: String?
        let reflectionNote: String?
        let createdAt: Date
    }

    /// Вызов экранов друга после `journal.addEntry`: запись уже на телефоне,
    /// здесь только досылаем её, не дожидаясь следующего изменения.
    func saveJournal(mood: Int?, urge: Int?, prompt: String?, note: String,
                     into journal: JournalManager) async {
        isSavingJournal = true
        defer { isSavingJournal = false }
        await syncJournal(journal)
    }

    /// Сверка в обе стороны: новое отсюда — на сервер, удалённое здесь —
    /// удалить там, появившееся там — добавить сюда.
    func syncJournal(_ journal: JournalManager) async {
        guard SupabaseConfig.isConfigured, !isSyncingJournal else { return }
        isSyncingJournal = true
        defer { isSyncingJournal = false }

        do {
            let me = try await SupabaseSession.shared.userID()
            let rows: [JournalRow] = try await db.select(
                "journal_entries", [],
                columns: "id,mood_score,urge_score,prompt_text,reflection_note,created_at")

            let remote = Set(rows.map(\.id))
            let local = Set(journal.entries.map(\.id))
            let synced = Set((defaults.stringArray(forKey: Key.syncedJournal) ?? []).compactMap(UUID.init))

            let deletedHere = synced.intersection(remote).subtracting(local)
            let deletedThere = synced.intersection(local).subtracting(remote)
            let newHere = local.subtracting(remote).subtracting(synced)
            let newThere = remote.subtracting(local).subtracting(synced)

            if !deletedHere.isEmpty {
                let list = deletedHere.map { $0.uuidString.lowercased() }.joined(separator: ",")
                try await db.delete("journal_entries", [("id", "in.(\(list))")])
            }

            let uploads = journal.entries.filter { newHere.contains($0.id) }
            try await db.insert("journal_entries", uploads.map {
                [
                    "id": $0.id.uuidString.lowercased(),
                    "user_id": me,
                    "reflection_note": $0.text,
                    "prompt_text": $0.promptQuestion,
                    "mood_score": $0.moodScore,
                    "urge_score": $0.urgeScore,
                    "created_at": PostgresTime.string(from: $0.date),
                ]
            })

            journal.applyRemote(
                added: rows.filter { newThere.contains($0.id) }.map {
                    JournalEntry(id: $0.id, date: $0.createdAt,
                                 text: $0.reflectionNote ?? "", promptQuestion: $0.promptText,
                                 moodScore: $0.moodScore, urgeScore: $0.urgeScore,
                                 isShieldReview: $0.promptText == JournalEntry.shieldBadge)
                },
                removed: deletedThere)

            let nowSynced = Set(journal.entries.map(\.id))
            defaults.set(nowSynced.map(\.uuidString), forKey: Key.syncedJournal)
        } catch {
            Self.log.error("journal sync failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Удаление аккаунта

    enum DeletionError: LocalizedError {
        case notConfigured
        var errorDescription: String? { String(localized: "Сервер не подключён — на нём нечего удалять.") }
    }

    /// Apple 5.1.1: удаление из приложения. Сервер стирает пользователя
    /// целиком (каскадом — профиль, дневник, срывы, напарника и сквад),
    /// потом чистится телефон. Если сервер не ответил, телефон не трогаем —
    /// повтор дойдёт до того же аккаунта.
    func deleteAccount(streak: StreakManager, journal: JournalManager,
                       checkIns: CheckInManager) async throws {
        guard SupabaseConfig.isConfigured else { throw DeletionError.notConfigured }
        try await db.call("delete_own_account")
        SupabaseSession.shared.signOut()

        streak.resetAll()
        journal.removeAll()
        checkIns.removeAll()
        RelapseLog.removeAll()
        TriggerLog.removeAll()
        for key in [Key.syncedJournal, Key.relapsesUploadedUntil] {
            defaults.removeObject(forKey: key)
        }
        notice = nil
    }
}
