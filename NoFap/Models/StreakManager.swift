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
        static let anchor = "streakAnchorDate"
        static let lastRelapse = "lastRelapseAt"
        static let lastFreeze = "lastStreakFreezeDate"
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

    /// Начало текущего стрика. Число дней на экране — календарная разница
    /// между этим моментом и сегодня, а не отдельный счётчик нажатий.
    private(set) var streakAnchor: Date?

    /// Момент последнего срыва. Нужен и офлайн-кэшу, и записи в relapses.
    private(set) var lastRelapseAt: Date?
    /// Последний раз, когда человек сохранил стрик щитом. Один раз на календарный месяц.
    private(set) var lastStreakFreezeDate: Date?

    /// Растёт при любой записи. Нужен, чтобы наблюдатели (синхронизация с
    /// напарником) реагировали на изменения, не перечисляя их по одному.
    /// Сам StreakManager по-прежнему ничего не знает ни о сети, ни о напарнике.
    private(set) var revision = 0

    /// Окно, в котором пропущенный день ещё не обнуляет серию.
    let gracePeriodHours: Double = 48

    /// Одно спокойное сообщение после автоматического сброса. HomeView гасит его.
    var streakResetNotice: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentStreak = defaults.integer(forKey: Key.currentStreak)
        bestStreak = defaults.integer(forKey: Key.bestStreak)
        totalCleanDays = defaults.integer(forKey: Key.totalClean)
        lastCheckinDate = defaults.object(forKey: Key.lastCheckin) as? Date
        streakAnchor = defaults.object(forKey: Key.anchor) as? Date
        lastRelapseAt = defaults.object(forKey: Key.lastRelapse) as? Date
        lastStreakFreezeDate = defaults.object(forKey: Key.lastFreeze) as? Date

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
        UserDefaults.standard.set(days, forKey: "userTargetStreakDays")
        persist()
    }

    /// Отмечался ли уже сегодня — чтобы не засчитывать день дважды.
    var hasCheckedInToday: Bool {
        hasCheckedIn(asOf: Date())
    }

    /// Щит ещё не тратили в этом календарном месяце.
    var canUseStreakFreeze: Bool {
        guard let last = lastStreakFreezeDate else { return true }
        return !calendar.isDate(last, equalTo: Date(), toGranularity: .month)
    }

    /// Запоминает использование щита. Счётчик дней не трогает.
    /// Возвращает прежнюю дату, чтобы отменить щит, если разбор не сохранили.
    @discardableResult
    func activateStreakFreeze(now: Date = Date()) -> Date? {
        let previous = lastStreakFreezeDate
        lastStreakFreezeDate = now
        persist()
        return previous
    }

    func restoreStreakFreeze(_ date: Date?) {
        lastStreakFreezeDate = date
        persist()
    }

    /// Конец 48-часового окна после последнего «Я держусь».
    var streakDeadlineDate: Date? {
        lastCheckinDate?.addingTimeInterval(gracePeriodHours * 3600)
    }

    func isCheckedIn(on date: Date) -> Bool {
        status(on: date) == true
    }

    /// Сколько осталось до полуночи, когда «Я держусь» снова можно нажать.
    /// nil — сегодня чистого чекина ещё не было.
    func nextCheckInRemaining(at date: Date = Date()) -> TimeInterval? {
        guard isCheckedIn(on: date) else { return nil }
        let start = calendar.startOfDay(for: date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let remaining = next.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    /// Часы до сгорания, округлённые вверх. nil — сегодня день уже закрыт
    /// или серии ещё нет, показывать дедлайн нечего.
    func hoursUntilDeadline(at date: Date = Date()) -> Int? {
        guard currentStreak > 0, let deadline = streakDeadlineDate, !hasCheckedIn(asOf: date) else { return nil }
        let remaining = deadline.timeIntervalSince(date)
        guard remaining > 0 else { return 0 }
        return max(1, Int((remaining / 3600).rounded(.up)))
    }

    /// Сброс только после двух суток без чекина. Пока 48 часов не вышли, серия жива.
    @discardableResult
    func checkStreakStatus(now: Date = Date()) -> Bool {
        guard let last = lastCheckinDate else { return false }
        guard now.timeIntervalSince(last) > gracePeriodHours * 3600 else { return false }
        guard currentStreak > 0 else { return false }
        currentStreak = 0
        streakAnchor = nil
        streakResetNotice = "Ты отсутствовал больше двух дней. Стрик обнулился, но твой опыт и сила аватара с тобой. Начни новую серию сегодня!"
        persist()
        return true
    }

    func acknowledgeStreakReset() {
        streakResetNotice = nil
    }

    /// Сколько осталось до конца суток после чистого «Я держусь».
    /// nil — таймер не идёт: срыва не было отсчёта или 24 часа уже прошли.
    func victoryCountdownRemaining(at date: Date = Date()) -> TimeInterval? {
        guard let last = lastCheckinDate, status(on: last) == true else { return nil }
        let remaining = 24 * 60 * 60 - date.timeIntervalSince(last)
        return remaining > 0 ? remaining : nil
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
        if !clean {
            recordRelapse(now: now)
            return true
        }
        guard !hasCheckedIn(asOf: now) else { return false }

        let before = currentStreak
        currentStreak += 1
        totalCleanDays += 1
        if streakAnchor == nil {
            streakAnchor = calendar.startOfDay(for: now)
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

    /// HomeView вызывает после того, как поздравление показано.
    func acknowledgeGoalReached() {
        justReachedGoal = false
    }

    /// Целые календарные дни от начала стрика до `now`. В день старта — 0.
    func elapsedDays(now: Date = Date()) -> Int {
        guard let streakAnchor else { return currentStreak }
        let start = calendar.startOfDay(for: streakAnchor)
        let today = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
    }

    /// На возврате в приложение проверяет 48-часовое окно, а не дописывает
    /// дни за время, пока человек не нажимал кнопку.
    @discardableResult
    func syncElapsedToToday(now: Date = Date()) -> Bool {
        checkStreakStatus(now: now)
    }

    /// Сервер — источник после успешной загрузки. До этого на экране уже
    /// лежит кэш из UserDefaults.
    func applyServerProfile(currentDays: Int, best: Int, start: Date?, lastRelapse: Date?, lastFreeze: Date? = nil) {
        if let start { streakAnchor = start }
        lastRelapseAt = lastRelapse
        if let lastFreeze { lastStreakFreezeDate = lastFreeze }
        bestStreak = max(best, bestStreak)
        if currentDays > currentStreak {
            currentStreak = currentDays
        }
        bestStreak = max(bestStreak, currentStreak)
        persist()
    }

    /// Срыв: рекорд забирает завершённую длину, отсчёт начинается заново.
    @discardableResult
    func recordRelapse(now: Date = Date()) -> Int {
        let finished = currentStreak
        if finished > bestStreak {
            bestStreak = finished
        }
        currentStreak = 0
        streakAnchor = now
        lastRelapseAt = now
        lastCheckinDate = now
        history[DayKey.string(from: now)] = false
        persist()
        return finished
    }

    /// Полный локальный сброс после удаления аккаунта.
    func resetAll() {
        currentStreak = 0
        bestStreak = 0
        totalCleanDays = 0
        lastCheckinDate = nil
        streakAnchor = nil
        lastRelapseAt = nil
        lastStreakFreezeDate = nil
        history = [:]
        justReachedGoal = false
        persist()
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
        defaults.set(streakAnchor, forKey: Key.anchor)
        defaults.set(lastRelapseAt, forKey: Key.lastRelapse)
        defaults.set(lastStreakFreezeDate, forKey: Key.lastFreeze)
        defaults.set(personalGoalDays, forKey: Key.goal)

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
