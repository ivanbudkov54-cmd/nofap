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
    @Environment(NotificationManager.self) private var notifications
    @Environment(AppRouter.self) private var router
    @Environment(Backend.self) private var backend
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(JournalManager.self) private var journal
    @Environment(BuddyManager.self) private var buddies
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
        .sheet(isPresented: Binding(
            get: { buddies.pendingBuddyCode != nil },
            set: { if !$0 { buddies.pendingBuddyCode = nil } }
        )) {
            PairBuddyConfirmationSheet()
        }
        .task {
            blocking.refresh()
            await reminder.refresh()
            await partner.refresh()
            streak.checkStreakStatus()
            await backend.bootstrap(streak: streak, journal: journal)
            bindNotificationTaps()
            await refreshLocalNotifications()
            if let userId = backend.currentUserId() {
                await subscriptions.identify(userId.uuidString)
            } else {
                await subscriptions.checkSubscriptionStatus()
            }
            if backend.currentUserId() != nil {
                await subscriptions.checkSubscription(backend: backend)
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
                if streak.hasCheckedInToday || streak.currentStreak == 0 {
                    notifications.cancelStreakWarning()
                }
                await refreshLocalNotifications()
            }
        }
        .onChange(of: journal.revision) { _, _ in
            if journal.hasWrittenToday() {
                notifications.cancelDiaryReminder()
            }
            Task { await refreshLocalNotifications() }
        }
        .onChange(of: hasCompletedOnboarding) { _, done in
            guard done, onboardingDone else { return }
            Task { await refreshLocalNotifications() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            streak.checkStreakStatus()
            Task {
                if backend.currentUserId() != nil {
                    await subscriptions.checkSubscription(backend: backend)
                }
                await partner.refresh()
                await refreshLocalNotifications()
            }
        }
    }

    private func refreshLocalNotifications() async {
        guard onboardingDone, hasCompletedOnboarding else { return }
        await notifications.scheduleDailyNotifications(streak: streak, journal: journal)
    }

    private func bindNotificationTaps() {
        notifications.onOpen = { destination in
            switch destination {
            case .home:
                router.selectedTab = 0
            case .diary:
                router.selectedTab = AppRouter.diaryTab
            case .knowledge:
                router.selectedTab = AppRouter.knowledgeTab
            }
        }
    }
}
