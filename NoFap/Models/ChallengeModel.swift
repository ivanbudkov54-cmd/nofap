//
//  ChallengeModel.swift
//  NoFap
//

import Foundation
import Observation
import UIKit

struct ChallengeItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let difficulty: Difficulty
    let category: String

    enum Difficulty: String, Codable {
        case easy = "Легкий"
        case medium = "Средний"
        case hard = "Хардкор"
    }
}

enum ChallengeLibrary {
    static let all: [ChallengeItem] = [
        ChallengeItem(
            id: "ch_1",
            title: "Мастер первого контакта",
            subtitle: "3 номера за вечер",
            detail: "За один вечер познакомься с тремя людьми и возьми контакт. Разговор живой, без скрипта в голове.",
            difficulty: .hard,
            category: "Социальная смелость"
        ),
        ChallengeItem(
            id: "ch_2",
            title: "Неожиданный комплимент",
            subtitle: "3 искренних комплимента",
            detail: "Скажи три комплимента разным людям — про поступок или характер, не про внешность ради реакции.",
            difficulty: .medium,
            category: "Социальная смелость"
        ),
        ChallengeItem(
            id: "ch_3",
            title: "Держи контакт глаз",
            subtitle: "Не отводи взгляд первым",
            detail: "В разговоре держи взгляд спокойно и не отводи его первым. Одна встреча — уже зачёт.",
            difficulty: .medium,
            category: "Уверенность"
        ),
        ChallengeItem(
            id: "ch_4",
            title: "Разговор в лифте или очереди",
            subtitle: "Спонтанный small-talk",
            detail: "Начни короткий разговор с незнакомцем в лифте, очереди или транспорте. Достаточно минуты.",
            difficulty: .easy,
            category: "Социальная смелость"
        ),
        ChallengeItem(
            id: "ch_5",
            title: "Одинокий ужин без экрана",
            subtitle: "40 минут в тишине",
            detail: "Поешь один, без телефона, видео и музыки. Сорок минут только еда и то, что вокруг.",
            difficulty: .medium,
            category: "Дофаминовый детокс"
        ),
        ChallengeItem(
            id: "ch_6",
            title: "Черно-белый мир",
            subtitle: "24 часа в монохроме",
            detail: "Сутки с чёрно-белым экраном. Цвет возвращается только когда день закончен.",
            difficulty: .medium,
            category: "Дофаминовый детокс"
        ),
        ChallengeItem(
            id: "ch_7",
            title: "Спальня без смартфона",
            subtitle: "Чистая зона сна",
            detail: "Телефон ночует вне спальни. Зарядка в другой комнате, будильник — отдельно.",
            difficulty: .hard,
            category: "Дисциплина"
        ),
        ChallengeItem(
            id: "ch_8",
            title: "Ледяной шок",
            subtitle: "2 минуты холодного душа",
            detail: "Две минуты под холодной водой. Дыши ровно и дойди до конца, не до «почти».",
            difficulty: .hard,
            category: "Тело и воля"
        ),
        ChallengeItem(
            id: "ch_9",
            title: "Сброс импульса: 100 отжиманий",
            subtitle: "Сброс за день сериями",
            detail: "Сто отжиманий за день, любыми сериями. Когда тянет к стимулу — ещё один подход.",
            difficulty: .hard,
            category: "Тело и воля"
        ),
        ChallengeItem(
            id: "ch_10",
            title: "Прогулка странника",
            subtitle: "10 000 шагов без наушников",
            detail: "Десять тысяч шагов без музыки и подкастов. Только улица и свои мысли.",
            difficulty: .medium,
            category: "Осознанность"
        )
    ]

    static func item(id: String) -> ChallengeItem? {
        all.first { $0.id == id }
    }
}

@MainActor
@Observable
final class ChallengeManager {

    private enum Key {
        static let current = "currentChallengeId"
        static let completed = "completedChallengeIds"
        static let history = "challengeHistoryIds"
        static let totalCount = "totalCompletedChallengesCount"
    }

    private(set) var currentChallengeId: String
    private(set) var completedChallengeIds: [String]
    private(set) var historyIds: [String]
    private(set) var totalCompletedChallengesCount: Int
    var showCompletion = false

    private let defaults: UserDefaults

    var level: Int {
        totalCompletedChallengesCount / ChallengeLibrary.all.count + 1
    }

    var current: ChallengeItem {
        ChallengeLibrary.item(id: currentChallengeId) ?? ChallengeLibrary.all[0]
    }

    var completedItems: [ChallengeItem] {
        historyIds.reversed().compactMap(ChallengeLibrary.item(id:))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Key.current)
        currentChallengeId = ChallengeLibrary.item(id: stored ?? "")?.id ?? ChallengeLibrary.all[0].id
        completedChallengeIds = defaults.stringArray(forKey: Key.completed) ?? []
        historyIds = defaults.stringArray(forKey: Key.history) ?? []
        totalCompletedChallengesCount = defaults.integer(forKey: Key.totalCount)
    }

    func completeCurrentChallenge() {
        let item = current
        if !completedChallengeIds.contains(item.id) {
            completedChallengeIds.append(item.id)
        }
        historyIds.append(item.id)
        totalCompletedChallengesCount += 1
        advance()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showCompletion = true
        persist()
    }

    private func advance() {
        if let next = ChallengeLibrary.all.first(where: { !completedChallengeIds.contains($0.id) }) {
            currentChallengeId = next.id
            return
        }
        completedChallengeIds = []
        currentChallengeId = ChallengeLibrary.all[0].id
    }

    private func persist() {
        defaults.set(currentChallengeId, forKey: Key.current)
        defaults.set(completedChallengeIds, forKey: Key.completed)
        defaults.set(historyIds, forKey: Key.history)
        defaults.set(totalCompletedChallengesCount, forKey: Key.totalCount)
    }
}
