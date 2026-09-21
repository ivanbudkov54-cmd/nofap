//
//  BlockingManager.swift
//  NoFap
//
//  Обёртка над Screen Time API. Фильтр `.auto()` использует встроенный
//  классификатор Apple: работает во всех браузерах и не требует
//  поддерживать собственный список доменов.
//

import Foundation
import FamilyControls
import ManagedSettings
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

    private let store = ManagedSettingsStore()

    private(set) var state: State = .unknown

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    /// Проверяет статус при запуске: если разрешение уже выдано, просто
    /// переустанавливает фильтр — настройки могли сброситься после обновления iOS.
    func refresh() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .denied:
            state = .denied
        case .notDetermined:
            state = .unknown
        default:
            // .approved, а с iOS 26 ещё и .approvedWithDataAccess.
            applyFilter()
        }
    }

    /// Запрашивает разрешение и сразу включает блокировку.
    func enableProtection() async {
        do {
            try await Self.requestAuthorization()
            applyFilter()
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

    /// `AuthorizationCenter` не Sendable, поэтому синглтон берётся уже внутри
    /// неизолированного контекста — иначе он уезжал бы с главного актора
    /// наружу, и это была бы гонка данных.
    private nonisolated static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    private func applyFilter() {
        store.webContent.blockedByFilter = .auto()
        state = .active
    }
}
