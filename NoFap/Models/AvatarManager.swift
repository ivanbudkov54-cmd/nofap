//
//  AvatarManager.swift
//  NoFap
//

import Foundation
import Observation

enum AvatarStage: Int, Codable, CaseIterable, Identifiable {
    case exhausted = 1
    case awakening = 2
    case athlete = 3
    case warrior = 4
    case titan = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .exhausted: "Истощенный"
        case .awakening: "Пробуждение"
        case .athlete: "Атлет"
        case .warrior: "Воин воли"
        case .titan: "Титан"
        }
    }

    /// Нижняя граница силы для этой формы.
    var floor: Int {
        switch self {
        case .exhausted: 0
        case .awakening: 101
        case .athlete: 301
        case .warrior: 701
        case .titan: 1500
        }
    }

    /// Сила, с которой открывается следующая форма. nil у последней.
    var nextThreshold: Int? {
        switch self {
        case .exhausted: 101
        case .awakening: 301
        case .athlete: 701
        case .warrior: 1500
        case .titan: nil
        }
    }

    static func stage(for power: Int) -> AvatarStage {
        switch power {
        case ..<101: .exhausted
        case ..<301: .awakening
        case ..<701: .athlete
        case ..<1500: .warrior
        default: .titan
        }
    }
}

@MainActor
@Observable
final class AvatarManager {

    private enum Key {
        static let power = "avatarCurrentPower"
        static let energy = "avatarCurrentEnergy"
        static let streak = "avatarStreakPower"
        static let challenges = "avatarChallengePower"
        static let articles = "avatarArticlePower"
        static let physical = "avatarPhysicalPower"
        static let read = "avatarReadArticleIds"
    }

    private(set) var currentPower: Int
    private(set) var currentEnergy: Int
    private(set) var streakPower: Int
    private(set) var challengePower: Int
    private(set) var articlePower: Int
    private(set) var physicalPower: Int
    private(set) var readArticleIds: Set<String>
    var pendingEvolution: AvatarStage?

    private let defaults: UserDefaults

    var stage: AvatarStage { AvatarStage.stage(for: currentPower) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentPower = defaults.integer(forKey: Key.power)
        let storedEnergy = defaults.object(forKey: Key.energy) as? Int
        currentEnergy = min(100, max(0, storedEnergy ?? 0))
        streakPower = defaults.integer(forKey: Key.streak)
        challengePower = defaults.integer(forKey: Key.challenges)
        articlePower = defaults.integer(forKey: Key.articles)
        physicalPower = defaults.integer(forKey: Key.physical)
        readArticleIds = Set(defaults.stringArray(forKey: Key.read) ?? [])
    }

    func addPowerForStreak() {
        grant(power: 25, energy: 20, into: \.streakPower)
    }

    func addPowerForChallenge() {
        grant(power: 15, energy: 15, into: \.challengePower)
    }

    /// Награда за физический сброс в момент тяги.
    func addPowerForPhysicalReset() {
        grant(power: 10, energy: 10, into: \.physicalPower)
    }

    func addPowerForVictory() {
        grant(power: 50, energy: 20, into: \.physicalPower)
    }

    @discardableResult
    func addPowerForArticle(id: String) -> Bool {
        guard readArticleIds.insert(id).inserted else { return false }
        grant(power: 10, energy: 10, into: \.articlePower)
        return true
    }

    func hasReadArticle(id: String) -> Bool {
        readArticleIds.contains(id)
    }

    /// Срыв без щита: энергия падает до 10%, сила теряет десятую часть.
    func applyRelapse() {
        currentEnergy = 10
        currentPower = Int((Double(currentPower) * 0.9).rounded(.down))
        persist()
    }

    func acknowledgeEvolution() {
        pendingEvolution = nil
    }

    func resetAll() {
        currentPower = 0
        currentEnergy = 0
        streakPower = 0
        challengePower = 0
        articlePower = 0
        physicalPower = 0
        readArticleIds = []
        pendingEvolution = nil
        persist()
    }

    private func grant(power: Int, energy: Int, into source: ReferenceWritableKeyPath<AvatarManager, Int>) {
        let before = stage
        self[keyPath: source] += power
        currentPower += power
        currentEnergy = min(100, currentEnergy + energy)
        let after = stage
        if after.rawValue > before.rawValue {
            pendingEvolution = after
        }
        persist()
    }

    private func persist() {
        defaults.set(currentPower, forKey: Key.power)
        defaults.set(currentEnergy, forKey: Key.energy)
        defaults.set(streakPower, forKey: Key.streak)
        defaults.set(challengePower, forKey: Key.challenges)
        defaults.set(articlePower, forKey: Key.articles)
        defaults.set(physicalPower, forKey: Key.physical)
        defaults.set(Array(readArticleIds), forKey: Key.read)
    }
}
