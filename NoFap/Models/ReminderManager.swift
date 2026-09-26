//
//  ReminderManager.swift
//  NoFap
//
//  Ежедневное напоминание перед часом тяги. Базовый час — из ответа
//  онбординга «в какое время суток тяга накатывает чаще». С Premium час
//  подстраивается под настоящие моменты тяги (см. UrgeClock).
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
    private static let baseHourKey = "reminderBaseHour"

    private(set) var state: State = .unknown

    /// Час начала опасного окна, под который сейчас стоит напоминание.
    private(set) var peakHour: Int?

    /// true — час взят из настоящих моментов тяги, а не из анкеты.
    private(set) var isPersonalized = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

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
            guard let request = pending.first(where: { $0.identifier == Self.identifier }) else {
                state = .off
                return
            }
            state = .scheduled
            if let hour = (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour {
                peakHour = (hour + 1) % 24
                // Напоминание поставлено до того, как базовый час начали
                // запоминать, — значит, оно ещё по анкете.
                if defaults.object(forKey: Self.baseHourKey) == nil {
                    defaults.set(peakHour, forKey: Self.baseHourKey)
                }
            }
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

        defaults.set(peakHour, forKey: Self.baseHourKey)
        await schedule(peakHour: peakHour, personalized: false)
    }

    /// Подстроить уже стоящее напоминание: под настоящий пик (`personalPeak`)
    /// или обратно под анкету (nil — нет Premium или мало данных).
    /// Выключенное или запрещённое не включает: это решение человека.
    func adapt(personalPeak: Int?) async {
        guard state == .scheduled else { return }
        let base = defaults.object(forKey: Self.baseHourKey) as? Int ?? peakHour
        guard let target = personalPeak ?? base else { return }
        guard target != peakHour || isPersonalized != (personalPeak != nil) else { return }
        await schedule(peakHour: target, personalized: personalPeak != nil)
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        state = .off
    }

    private func schedule(peakHour: Int, personalized: Bool) async {
        let content = UNMutableNotificationContent()
        if personalized {
            content.title = String(localized: "Скоро твой опасный час")
            content.body = String(localized: "По твоим отметкам тяга чаще приходит около \(peakHour):00. Реши заранее, чем займёшь этот час.")
        } else {
            content.title = String(localized: "Через час — опасное время")
            content.body = String(localized: "Обычно тяга накатывает примерно сейчас. Ты уже держишься — не срывай на ровном месте.")
        }
        content.sound = .default

        // Час до пика, с переходом через полночь: у «ночью» пик в 23, значит
        // напоминание в 22, а не в −1.
        var components = DateComponents()
        components.hour = (peakHour + 23) % 24
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            state = .scheduled
            self.peakHour = peakHour
            isPersonalized = personalized
        } catch {
            Self.log.error("Не удалось поставить напоминание: \(error.localizedDescription, privacy: .public)")
            state = .off
        }
    }
}
