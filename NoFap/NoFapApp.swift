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

    init() {
        Face.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(blocking)
                .environment(streak)
                .environment(partner)
                .preferredColorScheme(.dark)
        }
    }
}
