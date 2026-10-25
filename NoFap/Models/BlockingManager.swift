//
//  BlockingManager.swift
//  NoFap
//
//  Обёртка над Screen Time API. Два слоя:
//  1. Фильтр `.auto()` — встроенный классификатор Apple. Режет сайты 18+ во
//     всех браузерах, но при срабатывании показывает системную страницу
//     Safari: свой экран туда не подставить, и узнать о срабатывании нельзя.
//  2. Щит на сайты, которые человек сам выбрал как триггеры. Вместо них
//     iOS показывает наш экран (расширение ShieldConfiguration), а кнопка
//     «SOS» на нём ведёт в приложение (ShieldAction). Приложения не
//     закрываем никогда: в том же Telegram у человека вся переписка, а
//     отдельные чаты и каналы Экранное время различать не умеет.
//

import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications
import os

@Observable
final class BlockingManager {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "blocking")

    enum State {
        case unknown          // ещё не спрашивали разрешение
        case active           // защита работает
        case denied           // пользователь отказал в доступе
        case failed(String)   // ошибка при включении
    }

    /// Apple выдала разрешение на Family Controls.
    static let isAvailable = true

    private let store = ManagedSettingsStore()

    private(set) var state: State = .unknown

    /// Сайты и категории сайтов, которые человек сам закрыл щитом.
    private(set) var triggers: FamilyActivitySelection

    /// Сколько раз человек нажал кнопку на экране блокировки — то есть
    /// остановился. Пишет расширение, поэтому читаем при каждом показе.
    var stops: Int { ShieldShared.stops }

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    var triggerCount: Int {
        triggers.categoryTokens.count + triggers.webDomainTokens.count
    }

    init() {
        if let data = ShieldShared.defaults.data(forKey: ShieldShared.Key.selection),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            triggers = saved
        } else {
            triggers = FamilyActivitySelection()
        }
    }

    /// Проверяет статус при запуске: если разрешение уже выдано, просто
    /// переустанавливает настройки — они могли сброситься после обновления iOS.
    func refresh() {
        guard Self.isAvailable else { return }
        switch AuthorizationCenter.shared.authorizationStatus {
        case .denied:
            state = .denied
        case .notDetermined:
            state = .unknown
        default:
            // .approved, а с iOS 26 ещё и .approvedWithDataAccess.
            apply()
        }
    }

    /// Запрашивает разрешение и сразу включает блокировку.
    func enableProtection() async {
        do {
            try await Self.requestAuthorization()
            apply()
        } catch {
            // Раньше любая ошибка означала «пользователь отказал», и человека
            // отправляли в Настройки снимать запрет, которого он не ставил.
            // Отказ — это то, что подтверждает система, а не любой сбой.
            if AuthorizationCenter.shared.authorizationStatus == .denied {
                state = .denied
            } else {
                Self.log.error("Не удалось включить защиту: \(error.localizedDescription, privacy: .public)")
                state = .failed(String(localized: "Не удалось включить защиту. Попробуй ещё раз."))
            }
        }
    }

    /// Сохраняет выбор из FamilyActivityPicker и сразу ставит щит.
    func setTriggers(_ selection: FamilyActivitySelection) async {
        // Пикер Apple не умеет показывать только сайты, поэтому выбранные в
        // нём приложения просто отбрасываем.
        var selection = selection
        selection.applicationTokens = []
        triggers = selection
        if let data = try? JSONEncoder().encode(selection) {
            ShieldShared.defaults.set(data, forKey: ShieldShared.Key.selection)
        }
        if isActive { applyShield() }
        // Без уведомлений кнопка «SOS» на щите ничего не откроет.
        if triggerCount > 0 {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Экран блокировки рисует другой процесс — он видит только App Group.
    func updateShieldContext(streakDays: Int, quote: String?) {
        let defaults = ShieldShared.defaults
        defaults.set(streakDays, forKey: ShieldShared.Key.streakDays)
        defaults.set(quote, forKey: ShieldShared.Key.quote)
    }

    /// `AuthorizationCenter` не Sendable, поэтому синглтон берётся уже внутри
    /// неизолированного контекста — иначе он уезжал бы с главного актора
    /// наружу, и это была бы гонка данных.
    private nonisolated static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    private func apply() {
        store.webContent.blockedByFilter = .auto()
        applyShield()
        state = .active
    }

    private func applyShield() {
        // Сброс на случай, если старая версия успела закрыть приложения.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = triggers.webDomainTokens.isEmpty ? nil : triggers.webDomainTokens
        store.shield.webDomainCategories = triggers.categoryTokens.isEmpty
            ? nil : .specific(triggers.categoryTokens)
    }
}
