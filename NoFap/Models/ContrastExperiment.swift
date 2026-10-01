//
//  ContrastExperiment.swift
//  NoFap
//

import Foundation
import Observation

struct ContrastReviewModel: Codable, Equatable {
    var energy: Int
    var feelings: [String]
    var comparison: String
    var savedAt: Date
}

enum ContrastExperimentState: Codable, Equatable {
    case notStarted
    case activeWaitingReset
    case coolingDown(startedAt: Date, duration: TimeInterval)
    case readyForReview
    case completed(review: ContrastReviewModel)
}

@MainActor
@Observable
final class ContrastExperimentManager {

    private enum Key {
        static let state = "contrastExperimentState"
        static let cooldownHours = "experimentCooldownHours"
    }

    private(set) var state: ContrastExperimentState
    /// Длительность наблюдения после фиксации. По умолчанию сутки.
    var experimentCooldownHours: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hours = defaults.integer(forKey: Key.cooldownHours)
        experimentCooldownHours = hours == 0 ? 24 : hours
        if let data = defaults.data(forKey: Key.state),
           let decoded = try? JSONDecoder().decode(ContrastExperimentState.self, from: data) {
            state = decoded
        } else {
            state = .notStarted
        }
        refreshIfCooldownElapsed()
    }

    var cooldownEnd: Date? {
        guard case .coolingDown(let startedAt, let duration) = state else { return nil }
        return startedAt.addingTimeInterval(duration)
    }

    func start() {
        guard case .notStarted = state else { return }
        state = .activeWaitingReset
        persist()
    }

    func beginContrast() {
        guard case .activeWaitingReset = state else { return }
        let duration = TimeInterval(experimentCooldownHours * 3600)
        state = .coolingDown(startedAt: Date(), duration: duration)
        persist()
    }

    func refreshIfCooldownElapsed(now: Date = Date()) {
        guard case .coolingDown(let startedAt, let duration) = state else { return }
        guard now >= startedAt.addingTimeInterval(duration) else { return }
        state = .readyForReview
        persist()
    }

    func complete(energy: Int, feelings: [String], comparison: String) -> ContrastReviewModel {
        let review = ContrastReviewModel(
            energy: min(10, max(1, energy)),
            feelings: feelings,
            comparison: comparison.trimmingCharacters(in: .whitespacesAndNewlines),
            savedAt: Date()
        )
        state = .completed(review: review)
        persist()
        return review
    }

    static func journalNote(for review: ContrastReviewModel) -> String {
        let feelings = review.feelings.isEmpty ? "не отмечено" : review.feelings.joined(separator: ", ")
        return """
        #Контраст
        Энергия и ясность сейчас: \(review.energy)/10
        Сразу после сброса: \(feelings)
        \(review.comparison)
        """
    }

    private func persist() {
        defaults.set(experimentCooldownHours, forKey: Key.cooldownHours)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Key.state)
    }
}
