//
//  ReminderManager.swift
//  NoFap
//
//  Ежедневное напоминание перед часом тяги. Час берётся из ответа на
//  вопрос онбординга «в какое время суток тяга накатывает чаще» — до этого
//  ответ хранился, но ничем не использовался.
//

import Foundation
import UserNotifications
import os

@Observable
final class ReminderManager {

    enum State {
        case unknown      // ещё не спрашивали разрешение
        case scheduled    // напоминание стоит
        case denied       // пользователь отказал в уведомлениях
        case off          // разрешение есть, напоминание выключено
    }

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "reminder")
    private static let identifier = "urge-window-reminder"

    private(set) var state: State = .unknown

    /// Проверяет текущее состояние при запуске: разрешение могли отозвать
    /// в Настройках, а само напоминание — сброситься после обновления iOS.
    func refresh() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            state = .denied
        case .notDetermined:
            state = .unknown
        default:
            let pending = await center.pendingNotificationRequests()
            state = pending.contains { $0.identifier == Self.identifier } ? .scheduled : .off
        }
    }

    /// Запрашивает разрешение и ставит напоминание за час до пика тяги:
    /// смысл именно в том, чтобы успеть до того, как накроет, а не в момент.
    func enable(peakHour: Int) async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                state = .denied
                return
            }
        } catch {
            Self.log.error("Не удалось запросить разрешение на уведомления: \(error.localizedDescription, privacy: .public)")
            state = .denied
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Через час — опасное время")
        content.body = String(localized: "Обычно тяга накатывает примерно сейчас. Ты уже держишься — не срывай на ровном месте.")
        content.sound = .default

        // Час до пика, с переходом через полночь: у «ночью» пик в 23, значит
        // напоминание в 22, а не в −1.
        var components = DateComponents()
        components.hour = (peakHour + 23) % 24
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            state = .scheduled
        } catch {
            Self.log.error("Не удалось поставить напоминание: \(error.localizedDescription, privacy: .public)")
            state = .off
        }
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        state = .off
    }
}
