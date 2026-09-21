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

@Observable
@MainActor
final class BlockingManager {

    enum State {
        case unknown          // ещё не спрашивали разрешение
        case active           // защита работает
        case denied           // пользователь отказал в доступе
        case failed(String)   // ошибка при включении
    }

    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared

    private(set) var state: State = .unknown

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    /// Проверяет статус при запуске: если разрешение уже выдано, просто
    /// переустанавливает фильтр — настройки могли сброситься после обновления iOS.
    func refresh() {
        switch center.authorizationStatus {
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
        #if targetEnvironment(simulator)
        // Screen Time в симуляторе недоступен — включаем UI-состояние для разработки.
        state = .active
        return
        #endif

        do {
            try await center.requestAuthorization(for: .individual)
            applyFilter()
        } catch {
            state = .denied
        }
    }

    private func applyFilter() {
        #if targetEnvironment(simulator)
        state = .active
        return
        #endif

        store.webContent.blockedByFilter = .auto()
        state = .active
    }
}
