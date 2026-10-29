//
//  NoFapApp.swift
//  NoFap
//

import SwiftUI

@main
struct NoFapApp: App {

    init() {
        Face.register()
        NotificationRouter.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            RestoreGate()
                .onOpenURL { OpenRequest.shared.incomingURL = $0 }
        }
    }
}

/// Все менеджеры приложения. Живут здесь, а не в App: после восстановления
/// копии с сервера RestoreGate пересоздаёт этот экран, и менеджеры заново
/// читают UserDefaults.
struct AppRoot: View {

    @State private var blocking = BlockingManager()
    @State private var streak = StreakManager()
    @State private var partner = PartnerManager()
    @State private var squad = SquadManager()
    @State private var survey = SurveyManager()
    @State private var reasons = ReasonsStore()
    @State private var reminder = ReminderManager()
    @State private var notifications = NotificationManager()
    @State private var journal = JournalManager()
    @State private var checkIns = CheckInManager()
    @State private var premium = PremiumStore()
    @State private var cloud = CloudSync()
    @State private var router = AppRouter()
    @State private var theme = ThemeManager()
    @State private var challenges = ChallengeManager()
    @State private var contrast = ContrastExperimentManager()
    @State private var avatar = AvatarManager()
    @State private var tour = AppTourManager()
    @State private var xp = AvatarProgressManager()
    @State private var manifest = ManifestManager()

    var body: some View {
        ContentView()
            .environment(blocking)
            .environment(streak)
            .environment(partner)
            .environment(squad)
            .environment(survey)
            .environment(reasons)
            .environment(reminder)
            .environment(notifications)
            .environment(journal)
            .environment(checkIns)
            .environment(premium)
            .environment(cloud)
            .environment(router)
            .environment(theme)
            .environment(challenges)
            .environment(contrast)
            .environment(avatar)
            .environment(tour)
            .environment(xp)
            .environment(manifest)
    }
}
