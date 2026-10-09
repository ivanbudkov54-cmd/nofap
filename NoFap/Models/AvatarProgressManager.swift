//
//  AvatarProgressManager.swift
//  NoFap
//
//  Опыт (XP) и семь спартанских рангов аватара. Очки дают челленджи
//  (больше всего), дни стрика и прочитанные статьи (меньше всего). Пороги
//  рангов растут нелинейно: каждый следующий требует заметно больше.
//
//  Опыт копится на телефоне и дублируется в profiles.total_xp (см.
//  supabase/03_avatar_xp.sql). Без сервера всё работает так же.
//

import Foundation
import UIKit

// MARK: - Ранги

enum SpartanRank: Int, CaseIterable, Comparable, Identifiable {
    case initiate = 1
    case agoge
    case hoplite
    case veteran
    case polemarch
    case hippeus
    case leonidas

    var id: Int { rawValue }

    static func < (lhs: SpartanRank, rhs: SpartanRank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Суммарный опыт, с которого открывается ранг.
    var requiredXP: Int {
        switch self {
        case .initiate:  0
        case .agoge:     350
        case .hoplite:   1_000
        case .veteran:   2_200
        case .polemarch: 4_200
        case .hippeus:   7_500
        case .leonidas:  12_500
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .initiate:  "Илот / Неофит"
        case .agoge:     "Агог / Рекрут"
        case .hoplite:   "Гоплит"
        case .veteran:   "Спартанский ветеран"
        case .polemarch: "Полемарх"
        case .hippeus:   "Гиппей / Царская гвардия"
        case .leonidas:  "Леонид / Царь Спарты"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .initiate:  "Слабость ещё внутри. Но первый шаг сделан."
        case .agoge:     "Закаляется каждый день. Без поблажек."
        case .hoplite:   "Знает, откуда приходит тяга. И не сдаётся ей."
        case .veteran:   "Проходил через срывы и сомнения. Остался в строю."
        case .polemarch: "Сам решает, на что тратить силы. И тратит на дело."
        case .hippeus:   "Спокоен там, где другие ломаются."
        case .leonidas:  "Прошёл весь путь. Теперь на него равняются."
        }
    }

    var assetName: String { "spartan_rank_\(rawValue)" }

    /// Есть ли уже картинка этого ранга — пока нарисованы не все.
    var hasArtwork: Bool { UIImage(named: assetName) != nil }

    var next: SpartanRank? { SpartanRank(rawValue: rawValue + 1) }

    /// Самый высокий ранг, порог которого уже пройден.
    static func forXP(_ xp: Int) -> SpartanRank {
        allCases.last { xp >= $0.requiredXP } ?? .initiate
    }
}

/// Откуда пришёл опыт — для журнала и будущей статистики.
enum XPSource: String {
    case challenge, streak, article
}

// MARK: - Менеджер

@MainActor
@Observable
final class AvatarProgressManager {

    enum Reward {
        static let challenge = 100
        static let hardChallenge = 150
        static let streakDay = 50
        static let dailyArticle = 20
        static let scienceArticle = 30

        /// Бонус ровно в эти дни стрика, сверх ежедневных очков.
        static let milestones: [Int: Int] = [7: 100, 21: 250, 45: 500, 90: 1_000]
    }

    private enum Key {
        static let totalXP = "totalUserXP"
        static let readArticles = "readArticleIds"
        static let lastCelebrated = "lastCelebratedRank"
    }

    private let defaults: UserDefaults

    private(set) var totalXP: Int {
        didSet { defaults.set(totalXP, forKey: Key.totalXP) }
    }

    private var readArticleIDs: Set<String> {
        didSet { defaults.set(Array(readArticleIDs), forKey: Key.readArticles) }
    }

    private var lastCelebratedRank: Int {
        didSet { defaults.set(lastCelebratedRank, forKey: Key.lastCelebrated) }
    }

    /// Поднимается при переходе на новый ранг — экран показывает торжество.
    var showLevelUp = false
    private(set) var unlockedRank: SpartanRank = .initiate

    /// Отправка опыта на сервер. Задаёт CloudSync — менеджер о сети не знает.
    var onTotalChanged: ((Int) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        totalXP = max(0, defaults.integer(forKey: Key.totalXP))
        readArticleIDs = Set(defaults.stringArray(forKey: Key.readArticles) ?? [])
        let celebrated = defaults.integer(forKey: Key.lastCelebrated)
        lastCelebratedRank = celebrated > 0 ? celebrated : 1
        unlockedRank = SpartanRank.forXP(totalXP)
    }

    // MARK: - Производные значения

    var currentRank: SpartanRank { .forXP(totalXP) }
    var nextRank: SpartanRank? { currentRank.next }
    var currentLevelBaseXP: Int { currentRank.requiredXP }

    /// На последнем ранге цели нет — показываем его же порог.
    var nextLevelTargetXP: Int { nextRank?.requiredXP ?? currentRank.requiredXP }

    /// Доля пути внутри текущего ранга, 0…1. Ширина ранга всегда больше
    /// нуля, но проверка всё равно есть — деления на ноль не будет.
    var levelProgress: Double {
        guard let next = nextRank else { return 1 }
        let span = next.requiredXP - currentRank.requiredXP
        guard span > 0 else { return 1 }
        return min(max(Double(totalXP - currentRank.requiredXP) / Double(span), 0), 1)
    }

    var xpRemainingToNextLevel: Int {
        guard let next = nextRank else { return 0 }
        return max(next.requiredXP - totalXP, 0)
    }

    func hasRead(articleID: String) -> Bool { readArticleIDs.contains(articleID) }

    // MARK: - Начисление

    func addXP(_ amount: Int, source: XPSource) {
        guard amount > 0 else { return }
        let before = currentRank
        totalXP += amount
        let after = currentRank

        if after > before, after.rawValue > lastCelebratedRank {
            lastCelebratedRank = after.rawValue
            unlockedRank = after
            showLevelUp = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        onTotalChanged?(totalXP)
    }

    /// Одна и та же статья даёт очки только один раз.
    @discardableResult
    func rewardArticleRead(articleID: String, isScience: Bool) -> Bool {
        guard !readArticleIDs.contains(articleID) else { return false }
        readArticleIDs.insert(articleID)
        addXP(isScience ? Reward.scienceArticle : Reward.dailyArticle, source: .article)
        return true
    }

    func rewardChallengeCompleted(isHard: Bool) {
        addXP(isHard ? Reward.hardChallenge : Reward.challenge, source: .challenge)
    }

    /// Вызывается один раз на чистую отметку дня — `checkIn` сам не даёт
    /// отметиться дважды за день.
    func rewardStreakDay(_ streakDay: Int) {
        addXP(Reward.streakDay + (Reward.milestones[streakDay] ?? 0), source: .streak)
    }

    /// Полный сброс после удаления аккаунта.
    func resetAll() {
        totalXP = 0
        readArticleIDs = []
        lastCelebratedRank = 1
        unlockedRank = .initiate
        showLevelUp = false
    }
}
