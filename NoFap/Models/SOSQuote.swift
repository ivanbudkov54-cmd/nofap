//
//  SOSQuote.swift
//  NoFap
//

import Foundation

struct SOSQuote: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let text: String
    let author: String
    let tag: String
}

enum SOSQuoteLibrary {
    static let all: [SOSQuote] = [
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000001")!,
            text: "Никто не придет тебя спасать. Нет никакой волшебной кнопки. Есть только ты, твоя слабость и зеркало напротив.",
            author: "Дэвид Гоггинс",
            tag: "Самоконтроль"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000002")!,
            text: "Дисциплина — это делать то, что ты ненавидишь всем нутром, но делать это так, будто ты в этом лучший.",
            author: "Майк Тайсон",
            tag: "Характер"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000003")!,
            text: "У тебя есть власть над своим разумом, а не над внешними соблазнами. Осознай это — и ты обретешь непоколебимую силу.",
            author: "Марк Аврелий",
            tag: "Стоицизм"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000004")!,
            text: "Какое бесчестие для мужчины — состариться, так и не узнав, на какую силу, выносливость и красоту способно его тело.",
            author: "Сократ",
            tag: "Тело и дух"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000005")!,
            text: "Самый могущественный человек на земле — это тот, кто сумел подчинить самого себя.",
            author: "Сенека",
            tag: "Власть над собой"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000006")!,
            text: "Когда твой мозг шепчет, что ты истощен и пора сдаться, — ты израсходовал всего 40% своего истинного запаса прочности.",
            author: "Дэвид Гоггинс",
            tag: "Преодоление"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000007")!,
            text: "Сегодня я одержу победу над собой вчерашним; завтра я одержу победу над своей главной слабостью.",
            author: "Миямото Мусаси",
            tag: "Путь воина"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000008")!,
            text: "Не сдавайся сейчас. Потерпи дискомфорт сегодня — и проживи остаток жизни хозяином своей судьбы.",
            author: "Мухаммед Али",
            tag: "Фокус"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000009")!,
            text: "Победа — это не финал, срыв — это не приговор. Значение имеет только мужество продолжать путь.",
            author: "Уинстон Черчилль",
            tag: "Стойкость"
        ),
        SOSQuote(
            id: UUID(uuidString: "A1A1A1A1-0001-4000-8000-000000000010")!,
            text: "Первая и лучшая победа — это победа над своими желаниями. Капитулировать перед ними — самый горький из всех уделов.",
            author: "Платон",
            tag: "Разум"
        )
    ]
}

@MainActor
@Observable
final class SOSQuoteManager {
    private(set) var current: SOSQuote

    init() {
        current = SOSQuoteLibrary.all.randomElement() ?? SOSQuoteLibrary.all[0]
    }

    func show(_ quote: SOSQuote) {
        current = quote
    }

    @discardableResult
    func getRandomQuote() -> SOSQuote {
        let pool = SOSQuoteLibrary.all.filter { $0.id != current.id }
        current = pool.randomElement() ?? current
        return current
    }
}
