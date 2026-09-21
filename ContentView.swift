//
//  ContentView.swift
//  NoFap
//

import SwiftUI

struct ContentView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("onboardingDone") private var onboardingDone = false

    var body: some View {
        Group {
            if onboardingDone {
                RootView()
            } else {
                OnboardingView { onboardingDone = true }
            }
        }
        .task {
            streak.expireStreakIfNeeded()
            blocking.refresh()
            #if targetEnvironment(simulator)
            // В симуляторе Screen Time недоступен, а UI-клики из macOS не доходят —
            // завершаем онбординг программно, чтобы можно было смотреть главный экран.
            if !onboardingDone {
                await blocking.enableProtection()
                streak.markProtectionStart()
                onboardingDone = true
            }
            #endif
            await partner.refresh()
        }
        // Одна точка синхронизации на всё приложение. Дёргать push на каждом
        // вызове checkIn нельзя: мест вызова уже несколько, и каждое новое —
        // шанс забыть.
        .onChange(of: streak.revision) { _, _ in
            Task { await partner.push(from: streak) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            streak.expireStreakIfNeeded()
            Task { await partner.refresh() }
        }
    }
}
