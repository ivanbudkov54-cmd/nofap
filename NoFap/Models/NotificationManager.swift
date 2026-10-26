//
//  NotificationManager.swift
//  NoFap
//
//  Локальные пуши: стрик за 3 часа до сгорания 48-часового окна,
//  вечерний дневник и дневная база знаний. Без своего сервера —
//  только UNUserNotificationCenter и локальная зона устройства.
//  Нажатия разбирает NotificationRouter — делегат у центра уведомлений
//  один на всё приложение, вместе с SOS с экрана блокировки.
//

import Foundation
import UserNotifications
import os

nonisolated enum NotificationDestination: String {
    case home
    case diary
    case knowledge

    /// Ключ в userInfo уведомления.
    static let userInfoKey = "destination"
}

@Observable
final class NotificationManager {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "notifications")

    private enum ID {
        static let streak = "streak-warning-3h"
        static let diary = "diary-reminder"
        static let knowledge = "knowledge-reminder"
        static let test = "dev-test-notification"
        static let legacy = ["streak_warning_10h", "streak_final_1h"]
    }

    private enum Key {
        static let diaryFire = "notif.diary.fire"
        static let knowledgeFire = "notif.knowledge.fire"
    }

    private static let streakBodies = [
        "⚠️ Осталось 3 часа! Зайди и сохрани свой стрик в Spartan Pro.",
        "Твой прогресс под угрозой. Сделай отметку за день прямо сейчас!",
        "Не сбавляй темп. До сброса стрика осталось всего 3 часа.",
    ]

    private static let diaryBodies = [
        "Как прошел твой день? Зафиксируй мысли и состояние в дневнике.",
        "Вечерняя рефлексия: удели 2 минуты своему дневнику Spartan.",
        "Чистый разум начинается с честной записи. Заполни дневник за сегодня.",
    ]

    private static let knowledgeBodies = [
        "Новая порция знаний: прокачай дисциплину и прочитай короткий разбор.",
        "Знание — защита от срывов. Загляни в Базу знаний на 3 минуты.",
        "Узнай, как твой мозг справляется с триггерами: читай свежий материал.",
    ]

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Пересчитывает очередь на ближайшие 24–48 часов.
    func scheduleDailyNotifications(streak: StreakManager, journal: JournalManager) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ID.legacy)
        guard await isAuthorizedOrRequest() else { return }

        if streak.currentStreak == 0 || streak.hasCheckedInToday {
            cancelStreakWarning()
        } else if let deadline = streak.streakDeadlineDate {
            await scheduleStreakWarning(deadline: deadline)
        } else {
            cancelStreakWarning()
        }

        if journal.hasWrittenToday() {
            cancelDiaryReminder()
        } else {
            await scheduleDiaryReminder()
        }

        await scheduleKnowledgeReminder()
    }

    func cancelStreakWarning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.streak])
    }

    func cancelDiaryReminder() {
        defaults.removeObject(forKey: Key.diaryFire)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.diary])
    }

    func triggerTestNotification() async {
        guard await isAuthorizedOrRequest() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Spartan Pro"
        content.body = "Тестовое уведомление. Если ты это видишь — разрешения в порядке."
        content.sound = .default
        content.userInfo = [NotificationDestination.userInfoKey: NotificationDestination.home.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: ID.test, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Self.log.error("Не удалось поставить тестовое уведомление: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Permission

    private func isAuthorizedOrRequest() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                Self.log.error("Не удалось запросить разрешение: \(error.localizedDescription, privacy: .public)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule

    private func scheduleStreakWarning(deadline: Date) async {
        cancelStreakWarning()
        let raw = deadline.addingTimeInterval(-3 * 3600)
        guard let fire = shiftedOutOfQuiet(raw), fire < deadline else { return }
        await add(
            id: ID.streak,
            at: fire,
            title: "Стрик под угрозой",
            body: Self.streakBodies.randomElement() ?? Self.streakBodies[0],
            destination: .home
        )
    }

    private func scheduleDiaryReminder() async {
        let now = Date()
        if let stored = defaults.object(forKey: Key.diaryFire) as? Date, stored > now {
            await add(
                id: ID.diary,
                at: stored,
                title: "Дневник",
                body: Self.diaryBodies.randomElement() ?? Self.diaryBodies[0],
                destination: .diary
            )
            return
        }

        let todayWindow = randomTime(on: now, fromHour: 19, fromMinute: 30, toHour: 22, toMinute: 30)
        let fire: Date
        if let todayWindow, todayWindow > now {
            fire = todayWindow
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
                  let next = randomTime(on: tomorrow, fromHour: 19, fromMinute: 30, toHour: 22, toMinute: 30) {
            fire = next
        } else {
            return
        }

        guard let safe = shiftedOutOfQuiet(fire) else { return }
        defaults.set(safe, forKey: Key.diaryFire)
        await add(
            id: ID.diary,
            at: safe,
            title: "Дневник",
            body: Self.diaryBodies.randomElement() ?? Self.diaryBodies[0],
            destination: .diary
        )
    }

    private func scheduleKnowledgeReminder() async {
        let now = Date()
        if let stored = defaults.object(forKey: Key.knowledgeFire) as? Date, stored > now {
            await add(
                id: ID.knowledge,
                at: stored,
                title: "База знаний",
                body: Self.knowledgeBodies.randomElement() ?? Self.knowledgeBodies[0],
                destination: .knowledge
            )
            return
        }

        let todayWindow = randomTime(on: now, fromHour: 12, fromMinute: 0, toHour: 16, toMinute: 0)
        let fire: Date
        if let stored = defaults.object(forKey: Key.knowledgeFire) as? Date, stored <= now {
            let gap = Bool.random() ? 1 : 2
            guard let day = calendar.date(byAdding: .day, value: gap, to: calendar.startOfDay(for: now)),
                  let next = randomTime(on: day, fromHour: 12, fromMinute: 0, toHour: 16, toMinute: 0) else { return }
            fire = next
        } else if let todayWindow, todayWindow > now {
            fire = todayWindow
        } else {
            let gap = Bool.random() ? 1 : 2
            guard let day = calendar.date(byAdding: .day, value: gap, to: calendar.startOfDay(for: now)),
                  let next = randomTime(on: day, fromHour: 12, fromMinute: 0, toHour: 16, toMinute: 0) else { return }
            fire = next
        }

        guard let safe = shiftedOutOfQuiet(fire) else { return }
        defaults.set(safe, forKey: Key.knowledgeFire)
        await add(
            id: ID.knowledge,
            at: safe,
            title: "База знаний",
            body: Self.knowledgeBodies.randomElement() ?? Self.knowledgeBodies[0],
            destination: .knowledge
        )
    }

    private func add(id: String, at date: Date, title: String, body: String, destination: NotificationDestination) async {
        let horizon: TimeInterval = 48 * 3600
        let delay = date.timeIntervalSinceNow
        guard delay > 1, delay <= horizon else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [NotificationDestination.userInfoKey: destination.rawValue]

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Self.log.error("Не удалось поставить \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Time

    /// Ночь: 23:00–09:00 по локальному времени. Сдвигаем на 22:45 того же вечера.
    private func shiftedOutOfQuiet(_ date: Date) -> Date? {
        let hour = calendar.component(.hour, from: date)
        let isQuiet = hour >= 23 || hour < 9
        guard isQuiet else { return date }

        var day = date
        if hour < 9 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
            day = previous
        }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 22
        parts.minute = 45
        parts.second = 0
        guard let adjusted = calendar.date(from: parts), adjusted > Date() else { return nil }
        return adjusted
    }

    private func randomTime(on day: Date, fromHour: Int, fromMinute: Int, toHour: Int, toMinute: Int) -> Date? {
        let startOfDay = calendar.startOfDay(for: day)
        var startParts = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        startParts.hour = fromHour
        startParts.minute = fromMinute
        var endParts = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        endParts.hour = toHour
        endParts.minute = toMinute
        guard let start = calendar.date(from: startParts),
              let end = calendar.date(from: endParts),
              end > start else { return nil }
        let span = end.timeIntervalSince(start)
        return start.addingTimeInterval(TimeInterval.random(in: 0...span))
    }
}
