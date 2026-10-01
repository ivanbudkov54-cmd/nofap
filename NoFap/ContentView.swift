//
//  ContentView.swift
//  NoFap
//

import SwiftUI

struct ContentView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner
    @Environment(ReminderManager.self) private var reminder
    @Environment(Backend.self) private var backend
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(JournalManager.self) private var journal
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView { onboardingDone = true }
            } else if !hasCompletedOnboarding {
                OnboardingQuizView { hasCompletedOnboarding = true }
            } else {
                RootView()
            }
        }
        .task {
            blocking.refresh()
            await reminder.refresh()
            await partner.refresh()
            await backend.bootstrap(streak: streak, journal: journal)
            if let userId = backend.currentUserId() {
                await subscriptions.identify(userId.uuidString)
            } else {
                await subscriptions.checkSubscriptionStatus()
            }
        }
        .alert(backend.notice ?? "", isPresented: Binding(
            get: { backend.notice != nil },
            set: { if !$0 { backend.notice = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        }
        // Одна точка синхронизации на всё приложение. Дёргать push на каждом
        // вызове checkIn нельзя: мест вызова уже несколько, и каждое новое —
        // шанс забыть.
        .onChange(of: streak.revision) { _, _ in
            Task {
                await partner.push(from: streak)
                await backend.pushStreak(from: streak)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            streak.syncElapsedToToday()
            Task { await partner.refresh() }
        }
    }
}
