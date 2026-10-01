//
//  Backend.swift
//  NoFap
//
//  Гостевой вход, стрик, дневник и база знаний. Локальные менеджеры остаются
//  источником экрана: сеть только дополняет их и молча отступает, если
//  ключи не вставлены или нет интернета.
//

import Foundation
import os

@MainActor
@Observable
final class Backend {
    private let client = SupabaseClient()
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "Albert.lvan.NoFap", category: "supabase")
    private static let cacheKey = "knowledgeArticlesCache"

    private(set) var articles: [KnowledgeArticle] = []
    /// Ошибка для экрана профиля. Не всплывает алертом при тихом старте.
    var lastError: String?
    /// Ошибка действия пользователя: сохранение дневника или срыв.
    var notice: String?
    var isSavingJournal = false
    /// Пока идёт удаление, автосинхронизация стрика не должна создать
    /// новую сессию и записать в неё обнулённые данные раньше времени.
    var isDeletingAccount = false
    /// Сеть недоступна при старте: интерфейс остаётся на кэше, без спиннера.
    var isOffline = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode([KnowledgeArticle].self, from: data) {
            articles = cached
        }
    }

    func articles(tab: String) -> [KnowledgeArticle] {
        articles
            .filter { $0.tabType == tab }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func currentUserId() -> UUID? {
        client.currentUserId()
    }

    /// Анонимная сессия, затем стрик и статьи. Без ключей ничего не делает.
    func bootstrap(streak: StreakManager, journal: JournalManager) async {
        guard SupabaseConfig.isConfigured else { return }
        // Кэш уже на экране. Если сменился календарный день — число
        // пересчитывается до сети и уйдёт следом, когда сессия появится.
        streak.syncElapsedToToday()
        do {
            try await client.ensureSession()
            log.info("anonymous sign-in ok user=\(self.client.currentUserId()?.uuidString ?? "nil", privacy: .public)")
            let remote = try await client.pullProfile()
            streak.applyServerProfile(
                currentDays: remote.currentStreakDays,
                best: remote.bestStreakDays,
                start: remote.streakStartDate,
                lastRelapse: remote.lastRelapseAt,
                lastFreeze: remote.lastStreakFreezeDate
            )
            try await pushStreak(from: streak)
            try await refreshArticles()
            try await reloadJournal(into: journal)
            lastError = nil
            isOffline = false
            supabaseLog("launch connected user_id=\(self.client.currentUserId()?.uuidString ?? "nil")")
            log.info("bootstrap finished")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastError = message
            isOffline = (error as? SupabaseError)?.isOffline == true
            if isOffline {
                supabaseLog("launch offline, cached streak stays on screen")
            } else {
                supabaseLog("launch failed: \(message)")
            }
            log.error("bootstrap failed: \(message, privacy: .public)")
        }
    }

    func pushStreak(from streak: StreakManager) async {
        guard SupabaseConfig.isConfigured, !isDeletingAccount else { return }
        do {
            try await client.ensureSession()
            try await client.pushProfile(
                streakDays: streak.currentStreak,
                bestStreak: streak.bestStreak,
                streakStart: streak.streakAnchor,
                lastRelapse: streak.lastRelapseAt,
                lastFreeze: streak.lastStreakFreezeDate
            )
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Локальный срыв уже записан. Здесь — строка в relapses и обновление профиля.
    func syncRelapse(from streak: StreakManager, reason: String? = nil) async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            try await client.ensureSession()
            try await client.insertRelapse(at: streak.lastRelapseAt ?? Date(), reason: reason, notes: nil)
            try await client.pushProfile(
                streakDays: streak.currentStreak,
                bestStreak: streak.bestStreak,
                streakStart: streak.streakAnchor,
                lastRelapse: streak.lastRelapseAt,
                lastFreeze: streak.lastStreakFreezeDate
            )
            lastError = nil
            isOffline = false
            supabaseLog("relapse saved user_id=\(self.client.currentUserId()?.uuidString ?? "nil")")
        } catch {
            if (error as? SupabaseError)?.isOffline == true {
                isOffline = true
                notice = "Нет подключения к сети. Срыв сохранён локально"
                supabaseLog("relapse kept locally, network unavailable")
            } else {
                report(error)
            }
        }
    }

    func saveJournal(mood: Int?, urge: Int?, prompt: String?, note: String, into journal: JournalManager) async {
        guard SupabaseConfig.isConfigured else { return }
        isSavingJournal = true
        defer { isSavingJournal = false }
        do {
            try await client.ensureSession()
            try await client.insertJournal(mood: mood, urge: urge, prompt: prompt, note: note)
            try await reloadJournal(into: journal)
            lastError = nil
            isOffline = false
        } catch {
            if (error as? SupabaseError)?.isOffline == true {
                isOffline = true
                notice = "Нет подключения к сети. Запись сохранена локально"
                supabaseLog("journal kept locally, network unavailable")
            } else {
                report(error)
            }
        }
    }

    private func reloadJournal(into journal: JournalManager) async throws {
        let rows = try await client.fetchJournal()
        journal.replaceAll(rows.map {
            JournalEntry(
                id: $0.id,
                date: $0.createdAt,
                text: $0.reflectionNote ?? "",
                promptQuestion: $0.promptText,
                moodScore: $0.moodScore,
                urgeScore: $0.urgeScore,
                isShieldReview: $0.promptText == JournalEntry.shieldBadge
            )
        })
    }

    private func report(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastError = message
        notice = message
    }

    func deleteAccount(streak: StreakManager, journal: JournalManager, checkIns: CheckInManager) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        try await client.deleteAccount()
        streak.resetAll()
        journal.removeAll()
        checkIns.removeAll()
        articles = []
        defaults.removeObject(forKey: Self.cacheKey)
        lastError = nil
        notice = nil
        isOffline = false
        do {
            try await client.signInAnonymously()
            supabaseLog("new anonymous session after account deletion user_id=\(self.client.currentUserId()?.uuidString ?? "nil")")
        } catch {
            supabaseLog("account deleted, new session will start on next launch")
        }
    }

    private func refreshArticles() async throws {
        let remote = try await client.fetchArticles()
        articles = remote
        if let data = try? JSONEncoder().encode(remote) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

}
