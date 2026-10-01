//
//  NoFapApp.swift
//  NoFap
//

import RevenueCat
import SwiftUI

@main
struct NoFapApp: App {

    @State private var blocking = BlockingManager()
    @State private var streak = StreakManager()
    @State private var partner = PartnerManager()
    @State private var survey = SurveyManager()
    @State private var reasons = ReasonsStore()
    @State private var reminder = ReminderManager()
    @State private var journal = JournalManager()
    @State private var checkIns = CheckInManager()
    @State private var backend = Backend()
    @State private var subscriptions = SubscriptionManager()
    @State private var router = AppRouter()
    @State private var theme = ThemeManager()
    @State private var challenges = ChallengeManager()
    @State private var contrast = ContrastExperimentManager()
    @State private var avatar = AvatarManager()
    @State private var tour = AppTourManager()

    init() {
        Face.register()
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_nIUVvGauDnahVCDxjhnlvmuecXy")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(blocking)
                .environment(streak)
                .environment(partner)
                .environment(survey)
                .environment(reasons)
                .environment(reminder)
                .environment(journal)
                .environment(checkIns)
                .environment(backend)
                .environment(subscriptions)
                .environment(router)
                .environment(theme)
                .environment(challenges)
                .environment(contrast)
                .environment(avatar)
                .environment(tour)
                .preferredColorScheme(theme.theme.colorScheme)
        }
    }
}
