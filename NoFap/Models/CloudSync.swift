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
    }

    private var isSyncingJournal = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        let promptText: String?
        let reflectionNote: String?
        let createdAt: Date
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
                columns: "id,prompt_text,reflection_note,created_at")

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
                    "created_at": PostgresTime.string(from: $0.date),
                ]
            })

            journal.applyRemote(
                added: rows.filter { newThere.contains($0.id) }.map {
                    JournalEntry(id: $0.id, date: $0.createdAt,
                                 text: $0.reflectionNote ?? "", promptQuestion: $0.promptText)
                },
                removed: deletedThere)

            let nowSynced = Set(journal.entries.map(\.id))
            defaults.set(nowSynced.map(\.uuidString), forKey: Key.syncedJournal)
        } catch {
            Self.log.error("journal sync failed: \(String(describing: error), privacy: .public)")
        }
    }
}
