//
//  ReminderManager.swift
//  NoFap
//
//  Ежедневный вопрос «как ты?» за час до часа тяги. Базовый час — из ответа
//  онбординга «в какое время суток тяга накатывает чаще». С Pro час
//  подстраивается под настоящие моменты тяги (см. UrgeClock), а нажатие
//  открывает экспресс-чекин.
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
    /// Префикс идентификаторов: на каждый день своё уведомление, чтобы текст
    /// менялся. Старое повторяющееся напоминание жило ровно под этим именем.
    private static let identifier = "urge-window-reminder"
    private static let baseHourKey = "reminderBaseHour"
    private static let personalizedKey = "personalized"
    /// На сколько дней вперёд ставим. Приложение доставляет новые дни при
    /// каждом открытии; если не открывать две недели, вопросы прекратятся —
    /// это и правильно.
    private static let daysAhead = 14
    /// Если осталось меньше — пора доставить.
    private static let topUpThreshold = 7

    private(set) var state: State = .unknown

    /// Час начала опасного окна, под который сейчас стоит напоминание.
    private(set) var peakHour: Int?

    /// true — час взят из настоящих моментов тяги, а не из анкеты.
    private(set) var isPersonalized = false

    /// Нажатие открывает экспресс-чекин (Pro), иначе — главную.
    private var opensCheckIn = false
    private var scheduledThrough: Date?

    private let defaults: UserDefaults
    private let calendar = Calendar.current

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
                .filter { $0.identifier.hasPrefix(Self.identifier) }
            guard let first = pending.first else {
                state = .off
                return
            }
            state = .scheduled
            if let hour = (first.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour {
                peakHour = (hour + 1) % 24
                // Напоминание поставлено до того, как базовый час начали
                // запоминать, — значит, оно ещё по анкете.
                if defaults.object(forKey: Self.baseHourKey) == nil {
                    defaults.set(peakHour, forKey: Self.baseHourKey)
                }
            }
            isPersonalized = first.content.userInfo[Self.personalizedKey] as? Bool ?? false
            opensCheckIn = first.content.userInfo[NotificationDestination.userInfoKey] as? String
                == NotificationDestination.checkIn.rawValue
            // Старое повторяющееся напоминание не продлеваем — пусть adapt
            // заменит его ежедневными.
            scheduledThrough = first.identifier == Self.identifier ? nil : pending
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .max()
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
        await schedule(peakHour: peakHour, personalized: false, opensCheckIn: false)
    }

    /// Подстроить уже стоящее напоминание: под настоящий пик (`personalPeak`)
    /// или обратно под анкету (nil — нет Pro или мало данных) — и доставить
    /// дни вперёд. Выключенное или запрещённое не включает: это решение человека.
    func adapt(personalPeak: Int?, isPro: Bool) async {
        guard state == .scheduled else { return }
        let base = defaults.object(forKey: Self.baseHourKey) as? Int ?? peakHour
        guard let target = personalPeak ?? base else { return }
        let personalized = personalPeak != nil
        let unchanged = target == peakHour && isPersonalized == personalized && opensCheckIn == isPro
        if unchanged, let through = scheduledThrough,
           let threshold = calendar.date(byAdding: .day, value: Self.topUpThreshold, to: .now),
           through > threshold {
            return
        }
        await schedule(peakHour: target, personalized: personalized, opensCheckIn: isPro)
    }

    func disable() {
        Task { await removeAll() }
        state = .off
        scheduledThrough = nil
    }

    private func removeAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifier) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(peakHour: Int, personalized: Bool, opensCheckIn: Bool) async {
        await removeAll()

        // Час до пика, с переходом через полночь: у «ночью» пик в 23, значит
        // напоминание в 22, а не в −1.
        let hour = (peakHour + 23) % 24
        let destination: NotificationDestination = opensCheckIn ? .checkIn : .home
        let today = calendar.startOfDay(for: .now)
        var last: Date?

        for offset in 0..<Self.daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fire > .now else { continue }

            // Вариант по номеру дня в году: подряд не повторяются, а при
            // каждой перестановке день получает тот же текст.
            let index = calendar.ordinality(of: .day, in: .year, for: day) ?? offset
            let (title, body) = Self.text(index: index, peakHour: peakHour, personalized: personalized)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = [
                NotificationDestination.userInfoKey: destination.rawValue,
                Self.personalizedKey: personalized,
            ]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = "\(Self.identifier)-\(DayKey.string(from: day))"
            do {
                try await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                )
                last = fire
            } catch {
                Self.log.error("Не удалось поставить напоминание: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard last != nil else {
            state = .off
            return
        }
        state = .scheduled
        self.peakHour = peakHour
        isPersonalized = personalized
        self.opensCheckIn = opensCheckIn
        scheduledThrough = last
    }

    /// Вопрос вместо приказа: человек отвечает себе, как он, пока тяга
    /// ещё не накрыла.
    private static func text(index: Int, peakHour: Int, personalized: Bool) -> (String, String) {
        let variants: [(String, String)] = personalized
            ? [
                ("Как ты сейчас?", "По твоим отметкам тяга чаще приходит около \(peakHour):00. Отметься и реши заранее, чем займёшь этот час."),
                ("Как самочувствие?", "Около \(peakHour):00 у тебя обычно самое сложное время. Отметь, как ты, пока всё спокойно."),
                ("Что сейчас в голове?", "Через час твоё опасное время. Честный ответ себе — уже половина защиты."),
                ("Ты как?", "Скоро \(peakHour):00 — по твоим отметкам тянет именно тогда. Встреть этот час подготовленным."),
            ]
            : [
                ("Как ты сейчас?", "Скоро твоё сложное время. Отметь, как ты, — это 10 секунд."),
                ("Как самочувствие?", "Через час обычно накатывает тяга. Отметься — и встретишь её подготовленным."),
                ("Что сейчас в голове?", "Честный ответ самому себе — уже половина защиты. Как ты?"),
                ("Как прошёл день?", "Скоро опасный час. Остановись на минуту и посмотри, как ты."),
                ("Ты как?", "Через час время, когда обычно тянет. Реши заранее, чем займёшься."),
            ]
        return variants[index % variants.count]
    }
}
