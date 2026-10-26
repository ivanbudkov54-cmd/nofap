//
//  ContentView.swift
//  NoFap
//

import SwiftUI
import WidgetKit

struct ContentView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner
    @Environment(SquadManager.self) private var squad
    @Environment(ReminderManager.self) private var reminder
    @Environment(NotificationManager.self) private var notifications
    @Environment(PremiumStore.self) private var premium
    @Environment(JournalManager.self) private var journal
    @Environment(CloudSync.self) private var cloud
    @Environment(AvatarProgressManager.self) private var xp
    @Environment(AppBackup.self) private var backup
    @Environment(ManifestManager.self) private var manifest
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("onboardingDone") private var onboardingDone = false
    /// Опрос друга после нашего онбординга: стартовая точка, «Точка А» в дневнике.
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
            updateShieldContext()
            if backup.needsProtection {
                backup.needsProtection = false
                if BlockingManager.isAvailable, !blocking.isActive { await blocking.enableProtection() }
            }
            await reminder.refresh()
            await refreshLocalNotifications()
            await partner.refresh()
            await squad.refresh()
            await premium.start()
            await adaptReminder()
            await cloud.push(streak: streak)
            await cloud.syncJournal(journal)
            await cloud.refreshArticles()
            // Опыт — копия на сервере; менеджер о сети не знает.
            xp.onTotalChanged = { total in Task { await cloud.pushXP(total) } }
            await cloud.pushXP(xp.totalXP)
            await backup.upload()
        }
        .alert(cloud.notice ?? "", isPresented: Binding(
            get: { cloud.notice != nil },
            set: { if !$0 { cloud.notice = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        }
        // Одна точка синхронизации на всё приложение. Дёргать push на каждом
        // вызове checkIn нельзя: мест вызова уже несколько, и каждое новое —
        // шанс забыть.
        .onChange(of: streak.revision) { _, _ in
            Task { await partner.push(from: streak) }
            Task { await squad.push(from: streak, nickname: partner.nickname) }
            Task { await adaptReminder() }
            Task { await cloud.push(streak: streak) }
            updateShieldContext()
            if streak.hasCheckedInToday || streak.currentStreak == 0 {
                notifications.cancelStreakWarning()
            }
            Task { await refreshLocalNotifications() }
        }
        .onChange(of: manifest.currentManifest) { _, _ in
            updateShieldContext()
        }
        .onChange(of: journal.revision) { _, _ in
            Task { await cloud.syncJournal(journal) }
            if journal.hasWrittenToday() {
                notifications.cancelDiaryReminder()
            }
            Task { await refreshLocalNotifications() }
        }
        .onChange(of: hasCompletedOnboarding) { _, done in
            guard done, onboardingDone else { return }
            Task { await refreshLocalNotifications() }
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
            // Уход в фон — последний надёжный момент сохранить копию.
            if phase == .background { Task { await backup.upload(force: true) } }
            guard phase == .active else { return }
            Task { await partner.refresh() }
            Task { await squad.refresh() }
            Task { await cloud.syncJournal(journal) }
            Task { await refreshLocalNotifications() }
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
            if url == ShieldShared.sosURL {
                OpenRequest.shared.sos = true
                return
            }
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

    /// Напоминания о стрике, дневнике и знаниях — только после онбординга,
    /// чтобы запрос на уведомления не всплыл посреди анкеты.
    private func refreshLocalNotifications() async {
        guard onboardingDone, hasCompletedOnboarding else { return }
        await notifications.scheduleDailyNotifications(streak: streak, journal: journal)
    }

    /// Экран блокировки и виджет живут в других процессах и читают стрик,
    /// цель и строку из «Договора» из App Group.
    private func updateShieldContext() {
        blocking.updateShieldContext(
            streakDays: streak.currentStreak,
            quote: manifest.currentManifest?.shieldQuote
        )
        let shared = ShieldShared.defaults
        shared.set(streak.personalGoalDays, forKey: ShieldShared.Key.goalDays)
        shared.set(streak.lastCheckinDate, forKey: ShieldShared.Key.lastCheckin)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Умное напоминание — Pro: без подписки час всегда из анкеты,
    /// а нажатие ведёт на главную, а не в экспресс-чекин.
    private func adaptReminder() async {
        let peak = premium.isPremium
            ? UrgeClock.peakHour(sos: TriggerLog.entries(), relapses: RelapseLog.dates())
            : nil
        await reminder.adapt(personalPeak: peak, isPro: premium.isPremium)
    }
}
