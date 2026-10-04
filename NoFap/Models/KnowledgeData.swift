//
//  KnowledgeData.swift
//  NoFap
//
//  Вкладка «My Journey»: 45 дней программы. Тексты лежат в DailyFactsStore.
//

import Foundation

struct JourneyDay: Identifiable, Hashable {
    let day: Int
    let phaseTitle: String
    let title: String
    let biochemistry: String
    let realFeel: String
    let trapWarning: String
    let tacticalAction: String

    var id: Int { day }

    nonisolated init(fact: DailyFact) {
        day = fact.dayNumber
        phaseTitle = fact.phaseTitle
        title = fact.headline
        biochemistry = fact.biochemistry
        realFeel = fact.realFeel
        trapWarning = fact.trapWarning
        tacticalAction = fact.tacticalAction
    }
}

enum JourneyLibrary {
    static let totalDays = 45
    static let all: [JourneyDay] = DailyFactsStore.dailyFacts.map(JourneyDay.init)
}
