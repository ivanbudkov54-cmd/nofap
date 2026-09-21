//
//  StreakManager.swift
//  NoFap
//
//  Стрик и история чек-инов. Всё хранится локально в UserDefaults —
//  ни сервера, ни аккаунта, данные не покидают устройство.
//

import Foundation

@Observable
final class StreakManager {

    private enum Key {
        static let lastCheckin = "lastCheckinDate"
        static let currentStreak = "currentStreak"
        static let bestStreak = "bestStreak"
        static let totalClean = "totalCleanDays"
        static let startDate = "protectionStartDate"
        static let history = "checkInHistory"
        static let goal = "personalGoalDays"
        static let lastRelapse = "lastRelapseDate"
    }

    /// Личный срок, который человек поставил себе сам — не календарный месяц.
    private(set) var personalGoalDays: Int

    /// true ровно один раз — в момент, когда чек-ин перевёл currentStreak
    /// через personalGoalDays. HomeView должен сбросить флаг после показа
    /// поздравления, иначе оно будет всплывать при каждом открытии экрана.
    private(set) var justReachedGoal = false

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    /// День → отметился ли чисто. Ключ — "yyyy-MM-dd", без времени и часового
    /// пояса, чтобы не расходиться при смене региона устройства.
    private(set) var history: [String: Bool]

    private(set) var currentStreak: Int
    private(set) var bestStreak: Int
    private(set) var totalCleanDays: Int
    private(set) var lastCheckinDate: Date?

    /// Отдельная метка именно момента срыва — не путать с lastCheckinDate,
    /// который переиспользуется и чистыми чек-инами. Нужна, чтобы кнопка
    /// "Я ДЕРЖУСЬ" пряталась ровно на 24 часа от срыва, а не до полуночи:
    /// иначе она то пропадает, то появляется в зависимости от времени суток,
    /// когда произошёл срыв.
    private(set) var lastRelapseDate: Date?

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
        lastRelapseDate = defaults.object(forKey: Key.lastRelapse) as? Date

        if let data = defaults.data(forKey: Key.history),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            history = decoded
        } else {
            history = [:]
        }

        let storedGoal = defaults.integer(forKey: Key.goal)
        personalGoalDays = storedGoal > 0 ? storedGoal : 21

        // Если приложение не открывали больше суток, стрик к этому моменту
        // уже должен быть виден как обнулённый, а не ждать следующего
        // чек-ина — иначе Home и Progress ещё день-два показывали бы
        // устаревшее число.
        expireStreakIfNeeded()
    }

    func setGoal(_ days: Int) {
        guard days > 0 else { return }
        personalGoalDays = days
        justReachedGoal = false
        persist()
    }

    /// Отмечался ли уже сегодня — чтобы не засчитывать день дважды.
    var hasCheckedInToday: Bool {
        guard let last = lastCheckinDate else { return false }
        return calendar.isDateInToday(last)
    }

    /// Сутки после последнего чек-ина истекли: это не "сегодня" и не
    /// "вчера" относительно последней отметки. Именно "вчера" — специально,
    /// чтобы совпадать с условием продолжения стрика в checkIn(): пока
    /// человек укладывается в тот же зазор, где чек-ин ещё продолжил бы
    /// стрик, обнулять его автоматически нельзя.
    var isExpired: Bool {
        guard let last = lastCheckinDate else { return false }
        return !calendar.isDateInToday(last) && !calendar.isDateInYesterday(last)
    }

    /// Сколько ещё осталось ждать до того, как кнопка "Я ДЕРЖУСЬ" снова
    /// станет доступна — ровно 24 часа от момента срыва, а не до полуночи.
    /// nil, если кулдаун уже закончился или срывов ещё не было.
    func relapseCooldownRemaining(at date: Date = Date()) -> TimeInterval? {
        guard let last = lastRelapseDate else { return nil }
        let remaining = 24 * 60 * 60 - date.timeIntervalSince(last)
        return remaining > 0 ? remaining : nil
    }

    var isInRelapseCooldown: Bool {
        relapseCooldownRemaining() != nil
    }

    /// Обнуляет стрик, если сутки истекли, а нового чек-ина не было.
    /// Вызывается при старте и при возврате приложения на передний план,
    /// чтобы Home и Progress показывали ноль сразу, а не только после
    /// следующего действия пользователя.
    func expireStreakIfNeeded() {
        guard isExpired, currentStreak != 0 else { return }
        currentStreak = 0
        persist()
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

    @discardableResult
    func checkIn(clean: Bool, on date: Date = Date()) -> Bool {
        // Срыв перекрывает более ранний "чистый" чек-ин за те же сутки:
        // человек мог отметиться утром "Я ДЕРЖУСЬ", а сорваться вечером —
        // правда важнее правила "один чек-ин в день". Блокируем повторный
        // чек-ин только если пытаются второй раз отметиться чистым.
        guard !hasCheckedInToday || !clean else { return false }

        let alreadyCleanToday = status(on: date) == true
        let before = currentStreak

        if clean {
            // Стрик продолжается, только если вчера тоже отмечались.
            let continued = lastCheckinDate.map { calendar.isDateInYesterday($0) } ?? false
            currentStreak = continued ? currentStreak + 1 : 1
            totalCleanDays += 1
        } else {
            currentStreak = 0
            lastRelapseDate = date
            // Этот день уже был учтён как чистый — отменяем тот прирост,
            // иначе общий счётчик чистых дней окажется завышен.
            if alreadyCleanToday {
                totalCleanDays = max(0, totalCleanDays - 1)
            }
        }

        bestStreak = max(bestStreak, currentStreak)
        lastCheckinDate = date
        history[DayKey.string(from: date)] = clean

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

    /// Единственный путь записи — чтобы `revision` невозможно было забыть
    /// нарастить. Раньше `setGoal` писал ключ цели в обход этого метода;
    /// тогда изменение цели не долетало бы до напарника и «из N дней»
    /// у него протухало.
    private func persist() {
        defaults.set(currentStreak, forKey: Key.currentStreak)
        defaults.set(bestStreak, forKey: Key.bestStreak)
        defaults.set(totalCleanDays, forKey: Key.totalClean)
        defaults.set(lastCheckinDate, forKey: Key.lastCheckin)
        defaults.set(lastRelapseDate, forKey: Key.lastRelapse)
        defaults.set(personalGoalDays, forKey: Key.goal)
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Key.history)
        }
        revision += 1
    }
}
