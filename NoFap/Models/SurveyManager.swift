//
//  SurveyManager.swift
//  NoFap
//
//  Ответы вступительного опроса. Намеренно отдельно от StreakManager: там
//  любая запись поднимает `revision`, а ContentView превращает это в
//  `partner.push(...)`. Триггеры и обстановка — самые личные данные в
//  приложении, и пускать их через триггер синхронизации с напарником нельзя,
//  даже если сама посылка их не содержит.
//

import Foundation
import os

@Observable
final class SurveyManager {

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "survey")

    private enum Key {
        static let answers = "introSurveyAnswers"
    }

    private(set) var answers: IntroSurveyAnswers

    private let defaults: UserDefaults

    /// Трек не хранится отдельно: он полностью выводится из ответов, а второй
    /// источник правды разошёлся бы с ними. Но и пересобирать его на каждое
    /// обращение незачем — кэш сбрасывается ровно при изменении ответов.
    private var cachedTrack: PersonalTrack?

    var track: PersonalTrack {
        if let cachedTrack { return cachedTrack }
        let made = PersonalTrack.make(from: answers)
        cachedTrack = made
        return made
    }

    var isComplete: Bool {
        answers.completedAt != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Key.answers),
           let decoded = try? JSONDecoder().decode(IntroSurveyAnswers.self, from: data) {
            answers = decoded
        } else {
            answers = IntroSurveyAnswers()
        }
    }

    /// Один вход для правок — черновик сохраняется на каждом шаге, чтобы
    /// закрытое на середине приложение не стирало уже отвеченное.
    func update(_ mutate: (inout IntroSurveyAnswers) -> Void) {
        mutate(&answers)
        cachedTrack = nil
        persist()
    }

    func complete() {
        answers.completedAt = Date()
        persist()
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(answers), forKey: Key.answers)
        } catch {
            Self.log.error("Не удалось сохранить ответы опроса: \(error.localizedDescription, privacy: .public)")
        }
    }
}
