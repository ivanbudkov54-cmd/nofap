//
//  AvatarProgressManager.swift
//  NoFap
//

import Foundation
import Observation
import UIKit

enum XPSource: String {
    case challenge
    case streak
    case article
}

enum SpartanRank: Int, CaseIterable, Comparable, Identifiable {
    case initiate = 1
    case agoge = 2
    case hoplite = 3
    case veteran = 4
    case polemarch = 5
    case hippeus = 6
    case leonidas = 7

    var id: Int { rawValue }

    var requiredXP: Int {
        switch self {
        case .initiate: 0
        case .agoge: 350
        case .hoplite: 1_000
        case .veteran: 2_200
        case .polemarch: 4_200
        case .hippeus: 7_500
        case .leonidas: 12_500
        }
    }

    var title: String {
        switch self {
        case .initiate: "Илот / Неофит"
        case .agoge: "Агог / Рекрут"
        case .hoplite: "Гоплит"
        case .veteran: "Спартанский Ветеран"
        case .polemarch: "Полемарх"
        case .hippeus: "Гиппей / Царская гвардия"
        case .leonidas: "Леонид / Царь Спарты"
        }
    }

    var summary: String {
        switch self {
        case .initiate: "Сломленный импульсом, но решивший встать на путь."
        case .agoge: "Первые искры дисциплины. Начало суровой закалки."
        case .hoplite: "Крепкий щит и поставленный удар. Контроль базовых триггеров."
        case .veteran: "Прошел через сомнения и кризис. Разум побеждает плоть."
        case .polemarch: "Полководец своей жизни. Высокий уровень тестостерона и фокуса."
        case .hippeus: "Элита Спарты. Абсолютное хладнокровие и власть над собой."
        case .leonidas: "Живая легенда. Полная трансформация духа, тела и воли."
        }
    }

    var assetName: String { "spartan_rank_\(rawValue)" }

    static func < (lhs: SpartanRank, rhs: SpartanRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func rank(for xp: Int) -> SpartanRank {
        allCases.reversed().first { xp >= $0.requiredXP } ?? .initiate
    }
}

@MainActor
@Observable
final class AvatarProgressManager {
    private enum Key {
        static let totalXP = "totalUserXP"
        static let readArticles = "readArticleIds"
        static let lastCelebrated = "lastCelebratedRank"
    }

    private(set) var totalXP: Int
    private(set) var readArticleIds: Set<String>
    private(set) var lastCelebratedRank: Int
    var showLevelUpModal = false
    var unlockedRank: SpartanRank = .initiate

    private let defaults: UserDefaults

    var currentRank: SpartanRank { SpartanRank.rank(for: totalXP) }

    var nextRank: SpartanRank? {
        SpartanRank(rawValue: currentRank.rawValue + 1)
    }

    var currentLevelBaseXP: Int { currentRank.requiredXP }

    var nextLevelTargetXP: Int { nextRank?.requiredXP ?? currentRank.requiredXP }

    var levelProgress: Float {
        guard let next = nextRank else { return 1 }
        let span = next.requiredXP - currentRank.requiredXP
        guard span > 0 else { return 1 }
        let gained = totalXP - currentRank.requiredXP
        return Float(min(1, max(0, Double(gained) / Double(span))))
    }

    var xpRemainingToNextLevel: Int {
        guard let next = nextRank else { return 0 }
        return max(0, next.requiredXP - totalXP)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        totalXP = max(0, defaults.integer(forKey: Key.totalXP))
        lastCelebratedRank = max(1, defaults.object(forKey: Key.lastCelebrated) as? Int ?? 1)
        if let data = defaults.data(forKey: Key.readArticles),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            readArticleIds = Set(ids)
        } else {
            let legacy = defaults.stringArray(forKey: "avatarReadArticleIds") ?? []
            readArticleIds = Set(legacy)
        }
    }

    func addXP(amount: Int, source: XPSource) {
        guard amount > 0 else { return }
        let before = currentRank
        totalXP += amount
        let after = currentRank
        if after > before, after.rawValue > lastCelebratedRank {
            unlockedRank = after
            lastCelebratedRank = after.rawValue
            showLevelUpModal = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        persist()
        let xp = totalXP
        Task { await SupabaseClient().pushTotalXP(xp) }
        _ = source
    }

    func rewardArticleRead(articleId: String, isScience: Bool) {
        guard readArticleIds.insert(articleId).inserted else { return }
        addXP(amount: isScience ? 30 : 20, source: .article)
    }

    func rewardChallengeCompleted(isSocial: Bool) {
        addXP(amount: isSocial ? 150 : 100, source: .challenge)
    }

    func rewardStreakDaily(streakDay: Int) {
        var amount = 50
        if streakDay == 90 {
            amount += 1_000
        } else if streakDay == 45 {
            amount += 500
        } else if streakDay == 21 {
            amount += 250
        } else if streakDay > 0, streakDay.isMultiple(of: 7) {
            amount += 100
        }
        addXP(amount: amount, source: .streak)
    }

    func hasReadArticle(id: String) -> Bool {
        readArticleIds.contains(id)
    }

    func resetAll() {
        totalXP = 0
        readArticleIds = []
        lastCelebratedRank = 1
        showLevelUpModal = false
        unlockedRank = .initiate
        persist()
    }

    private func persist() {
        defaults.set(totalXP, forKey: Key.totalXP)
        defaults.set(lastCelebratedRank, forKey: Key.lastCelebrated)
        let data = (try? JSONEncoder().encode(Array(readArticleIds))) ?? Data()
        defaults.set(data, forKey: Key.readArticles)
    }
}
