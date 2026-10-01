//
//  ContentView.swift
//  NoFap
//

import SwiftUI

struct ContentView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner
    @Environment(SquadManager.self) private var squad
    @Environment(ReminderManager.self) private var reminder
    @Environment(PremiumStore.self) private var premium
    @Environment(JournalManager.self) private var journal
    @Environment(CloudSync.self) private var cloud
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
            await squad.refresh()
            await premium.start()
            await adaptReminder()
            await cloud.push(streak: streak)
            await cloud.syncJournal(journal)
        }
        // Одна точка синхронизации на всё приложение. Дёргать push на каждом
        // вызове checkIn нельзя: мест вызова уже несколько, и каждое новое —
        // шанс забыть.
        .onChange(of: streak.revision) { _, _ in
            Task { await partner.push(from: streak) }
            Task { await squad.push(from: streak, nickname: partner.nickname) }
            Task { await adaptReminder() }
            Task { await cloud.push(streak: streak) }
        }
        .onChange(of: journal.revision) { _, _ in
            Task { await cloud.syncJournal(journal) }
        }
        // И сразу, как только появилась пара или приглашение: иначе
        // напарник видел бы нули до первой отметки.
        .onChange(of: partner.state) { _, _ in
            Task { await partner.push(from: streak) }
        }
        .onChange(of: squad.isInSquad) { _, _ in
            Task { await squad.push(from: streak, nickname: partner.nickname) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await partner.refresh() }
            Task { await squad.refresh() }
            Task { await cloud.syncJournal(journal) }
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
            guard let invite = PartnerLink.invite(from: url) else { return }
            switch invite.kind {
            case .partner:
                partner.pendingInviter = invite.inviter
                partner.pendingCode = invite.code
            case .squad:
                squad.pendingInviter = invite.inviter
                squad.pendingCode = invite.code
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
