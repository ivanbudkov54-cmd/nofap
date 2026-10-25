//
//  ShieldActionExtension.swift
//  ShieldAction
//
//  Кнопки на экране блокировки. Открыть приложение отсюда iOS не даёт,
//  поэтому «Открыть SOS» закрывает заблокированное приложение и сразу
//  присылает уведомление — нажатие на него открывает SOS в StopFap.
//

import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Любая кнопка — это человек, который остановился, а не пролистал дальше.
        ShieldShared.recordStop()

        if action == .primaryButtonPressed {
            postSOSNotification()
        }
        completionHandler(.close)
    }

    /// Ждём, пока уведомление поставится: после ответа `.close` процесс
    /// расширения могут выгрузить, и запрос не успел бы уйти.
    private func postSOSNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ты остановился. Это уже победа."
        content.body = "Нажми — откроется SOS. Переждём волну вместе."
        content.sound = .default
        content.userInfo = [ShieldShared.sosUserInfoKey: ShieldShared.sosUserInfoValue]

        let request = UNNotificationRequest(
            identifier: "shield-sos",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        let done = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { _ in done.signal() }
        _ = done.wait(timeout: .now() + 2)
    }
}
