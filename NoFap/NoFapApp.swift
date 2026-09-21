//
//  NoFapApp.swift
//  NoFap
//

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

    init() {
        Face.register()
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
                .preferredColorScheme(.dark)
        }
    }
}
