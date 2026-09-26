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
    @Environment(PremiumStore.self) private var premium
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
            blocking.refresh()
            await reminder.refresh()
            await partner.refresh()
            await premium.start()
            await adaptReminder()
        }
        // Одна точка синхронизации на всё приложение. Дёргать push на каждом
        // вызове checkIn нельзя: мест вызова уже несколько, и каждое новое —
        // шанс забыть.
        .onChange(of: streak.revision) { _, _ in
            Task { await partner.push(from: streak) }
            Task { await adaptReminder() }
        }
        // И сразу, как только появилась пара или приглашение: иначе
        // напарник видел бы нули до первой отметки.
        .onChange(of: partner.state) { _, _ in
            Task { await partner.push(from: streak) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await partner.refresh() }
            Task {
                await premium.refreshEntitlements()
                await adaptReminder()
            }
        }
        .onChange(of: premium.isPremium) { _, _ in
            Task { await adaptReminder() }
        }
        // Здесь, а не в RootView: ссылку могут открыть ещё до конца
        // онбординга — код подождёт в менеджере, пока появятся вкладки.
        .onOpenURL { url in
            if let code = PartnerLink.code(from: url) {
                partner.pendingCode = code
            }
        }
    }

    /// Умное напоминание — Premium: без подписки час всегда из анкеты.
    private func adaptReminder() async {
        let peak = premium.isPremium
            ? UrgeClock.peakHour(sos: TriggerLog.entries(), relapses: RelapseLog.dates())
            : nil
        await reminder.adapt(personalPeak: peak)
    }
}
