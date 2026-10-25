//
//  NotificationRouter.swift
//  NoFap
//
//  Делегат уведомлений. Нажатие на уведомление с экрана блокировки
//  открывает SOS. Ставится в init приложения — до того, как iOS передаст
//  нажатие, иначе при холодном запуске оно потеряется.
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
        guard info[ShieldShared.sosUserInfoKey] as? String == ShieldShared.sosUserInfoValue else { return }
        await MainActor.run { SOSLaunch.shared.requested = true }
    }

    /// Без этого уведомления, пришедшие при открытом приложении, iOS прячет.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
