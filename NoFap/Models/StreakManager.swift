//
//  StreakManager.swift
//  NoFap
//
//  Стрик и история чек-инов. Хранится локально в UserDefaults — ни аккаунта,
//  ни своего сервера. Если человек сам позвал напарника, наружу уезжает
//  только счёт дней, цель и день последней отметки (см. PartnerManager).
//  История по дням не покидает устройство никогда.
//

import Foundation
import os

@Observable
final class StreakManager {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "streak")

    private enum Key {
        static let lastCheckin = "lastCheckinDate"
        static let currentStreak = "currentStreak"
        static let bestStreak = "bestStreak"
        static let totalClean = "totalCleanDays"
        static let startDate = "protectionStartDate"
        static let history = "checkInHistory"
        static let goal = "personalGoalDays"
        static let lastShield = "lastStreakFreezeDate"
    }

    /// Личный срок, который человек поставил себе сам — не календарный месяц.
    private(set) var personalGoalDays: Int

    /// true ровно один раз — в момент, когда чек-ин перевёл currentStreak
    /// через personalGoalDays. HomeView должен сбросить флаг после показа
    /// поздравления, иначе оно будет всплывать при каждом открытии экрана.
    private(set) var justReachedGoal = false

    private let defaults: UserDefaults

    /// `autoupdatingCurrent`, а не снимок `Calendar.current` при инициализации:
    /// менеджер живёт всё время работы приложения, и после смены часового
    /// пояса застывший календарь начал бы спорить с ключами дней из DayKey.
    private var calendar: Calendar { .autoupdatingCurrent }

    /// День → отметился ли чисто. Ключ — "yyyy-MM-dd", без времени и часового
    /// пояса, чтобы не расходиться при смене региона устройства.
    private(set) var history: [String: Bool]

    private(set) var currentStreak: Int
    private(set) var bestStreak: Int
    private(set) var totalCleanDays: Int
    private(set) var lastCheckinDate: Date?

    /// Когда последний раз сохраняли стрик щитом. Щит — раз в календарный месяц.
    private(set) var lastShieldDate: Date?

    /// Растёт при любой записи. Нужен, чтобы наблюдатели (синхронизация с
    /// напарником) реагировали на изменения, не перечисляя их по одному.
    /// Сам StreakManager по-прежнему ничего не знает ни о сети, ни о напарнике.
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentStreak = defaults.integer(forKey: Key.currentStreak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
        totalCleanDays = defaults.integer(forKey: Key.totalClean)
        lastCheckinDate = defaults.object(forKey: Key.lastCheckin) as? Date
        lastShieldDate = defaults.object(forKey: Key.lastShield) as? Date

        if let data = defaults.data(forKey: Key.history),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            history = decoded
        } else {
            history = [:]
        }

        let storedGoal = defaults.integer(forKey: Key.goal)
        personalGoalDays = storedGoal > 0 ? storedGoal : 21
    }

    func setGoal(_ days: Int) {
        guard days > 0 else { return }
        personalGoalDays = days
        justReachedGoal = false
        persist()
    }

    /// Отмечался ли уже сегодня — чтобы не засчитывать день дважды.
    var hasCheckedInToday: Bool {
        hasCheckedIn(asOf: Date())
    }

    private func hasCheckedIn(asOf now: Date) -> Bool {
        guard let last = lastCheckinDate else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }

    /// Дата, с которой пользователь включил защиту.
    var protectionStartDate: Date? {
        defaults.object(forKey: Key.startDate) as? Date
    }

    func markProtectionStart() {
        guard protectionStartDate == nil else { return }
        defaults.set(Date(), forKey: Key.startDate)
    }

    /// nil — за этот день ещё не отмечались.
    func status(on date: Date) -> Bool? {
        history[DayKey.string(from: date)]
    }

    /// Все проверки считаются от `now`, а не часть от него и часть от
    /// системного «сейчас». Раньше параметр назывался `on date:` и влиял
    /// только на ключ в истории, а «отмечался ли сегодня» и «было ли вчера»
    /// брались от текущего момента — передача любой другой даты молча
    /// разъезжалась со стриком. Параметр остаётся ради тестируемости.
    @discardableResult
    func checkIn(clean: Bool, now: Date = Date()) -> Bool {
        // Срыв засчитывается и после утреннего «Держусь»: иначе честная
        // отметка вечером молча терялась бы. Чистый день — только раз.
        let todayKey = DayKey.string(from: now)
        if !clean, history[todayKey] == true {
            totalCleanDays = max(0, totalCleanDays - 1)
        } else if hasCheckedIn(asOf: now) {
            return false
        }

        let before = currentStreak

        if clean {
            // Стрик продолжается, только если отмечались в предыдущий день
            // относительно `now`.
            let continued: Bool
            if let last = lastCheckinDate,
               let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
                continued = calendar.isDate(last, inSameDayAs: yesterday)
            } else {
                continued = false
            }

            currentStreak = continued ? currentStreak + 1 : 1
            totalCleanDays += 1
        } else {
            currentStreak = 0
        }

        bestStreak = max(bestStreak, currentStreak)
        lastCheckinDate = now
        history[DayKey.string(from: now)] = clean

        // Флаг встаёт только в момент перехода через порог, а не каждый раз,
        // когда currentStreak уже выше цели — иначе поздравление лезло бы
        // при каждом следующем чек-ине после победы.
        if personalGoalDays > 0 && before < personalGoalDays && currentStreak >= personalGoalDays {
            justReachedGoal = true
        }

        persist()
        return true
    }

    // MARK: - Щит стрика

    /// Щит в этом календарном месяце ещё не тратили.
    var canUseShield: Bool {
        guard let last = lastShieldDate else { return true }
        return !calendar.isDate(last, equalTo: Date(), toGranularity: .month)
    }

    /// Срыв без обнуления — после честного разбора. День в календаре
    /// честно отмечается срывом, но счёт не трогается, и завтрашнее
    /// «Держусь» продолжит стрик, а не начнёт его заново.
    @discardableResult
    func useShield(now: Date = Date()) -> Bool {
        guard canUseShield else { return false }
        let todayKey = DayKey.string(from: now)
        if history[todayKey] == true {
            // Сегодня уже отмечался чистым — день был засчитан в стрик и
            // остаётся в нём, но чистым его больше не назвать.
            totalCleanDays = max(0, totalCleanDays - 1)
        }
        history[todayKey] = false
        lastCheckinDate = now
        lastShieldDate = now
        persist()
        return true
    }

    /// Полный локальный сброс после удаления аккаунта. Цель остаётся —
    /// это настройка, а не история.
    func resetAll() {
        currentStreak = 0
        bestStreak = 0
        totalCleanDays = 0
        lastCheckinDate = nil
        lastShieldDate = nil
        history = [:]
        justReachedGoal = false
        defaults.removeObject(forKey: Key.startDate)
        persist()
    }

    /// HomeView вызывает после того, как поздравление показано.
    func acknowledgeGoalReached() {
        justReachedGoal = false
    }

    /// Единственный путь записи — чтобы `revision` невозможно было забыть
    /// нарастить. Раньше `setGoal` писал ключ цели в обход этого метода;
    /// тогда изменение цели не долетало бы до напарника и «из N дней»
    /// у него протухало.
    private func persist() {
        defaults.set(currentStreak, forKey: Key.currentStreak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
        defaults.set(totalCleanDays, forKey: Key.totalClean)
        defaults.set(lastCheckinDate, forKey: Key.lastCheckin)
        defaults.set(personalGoalDays, forKey: Key.goal)
        defaults.set(lastShieldDate, forKey: Key.lastShield)

        do {
            defaults.set(try JSONEncoder().encode(history), forKey: Key.history)
        } catch {
            // Молчаливое `try?` здесь означало бы потерянный календарь без
            // единого следа. Счётчики уже записаны, поэтому не прерываемся.
            Self.log.error("Не удалось сохранить историю дней: \(error.localizedDescription, privacy: .public)")
        }

        revision += 1
    }
}
