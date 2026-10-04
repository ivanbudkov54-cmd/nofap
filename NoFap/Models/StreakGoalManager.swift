//
//  StreakGoalManager.swift
//  NoFap
//

import UIKit

@MainActor
@Observable
final class StreakGoalManager {
    private let key = "lastCelebratedGoalDays"
    var showVictoryScreen = false

    var lastCelebratedGoalDays: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    func checkGoalCompletion(currentStreak: Int, targetDays: Int) {
        guard targetDays > 0, currentStreak >= targetDays, targetDays > lastCelebratedGoalDays else { return }
        lastCelebratedGoalDays = targetDays
        showVictoryScreen = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func nextTarget(after days: Int) -> Int {
        StreakTarget.allCases.map(\.days).first { $0 > days } ?? days
    }
}
