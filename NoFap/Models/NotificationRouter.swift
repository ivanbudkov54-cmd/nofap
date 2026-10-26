//
//  NotificationRouter.swift
//  NoFap
//
//  Делегат уведомлений — один на всё приложение. Уведомление с экрана
//  блокировки открывает SOS, напоминания — свою вкладку. Ставится в init
//  приложения — до того, как iOS передаст нажатие, иначе при холодном
//  запуске оно потеряется.
//

import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if info[ShieldShared.sosUserInfoKey] as? String == ShieldShared.sosUserInfoValue {
            await MainActor.run { OpenRequest.shared.sos = true }
            return
        }
        guard let raw = info[NotificationDestination.userInfoKey] as? String,
              let destination = NotificationDestination(rawValue: raw) else { return }
        await MainActor.run { OpenRequest.shared.destination = destination }
    }

    /// Без этого уведомления, пришедшие при открытом приложении, iOS прячет.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
