//
//  ProFeature.swift
//  NoFap
//
//  Функции Spartan Pro. По нажатию на закрытую функцию пейвол сначала
//  объясняет именно её — что она даёт, — а уже потом предлагает Pro.
//

import Foundation

enum ProFeature: String, CaseIterable, Identifiable {
    case checkIn
    case analytics
    case avatar
    case squad
    case journey
    case simulator
    case articles

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .checkIn:   "gauge.with.dots.needle.50percent"
        case .analytics: "chart.bar.fill"
        case .avatar:    "figure.strengthtraining.traditional"
        case .squad:     "person.3.fill"
        case .journey:   "map.fill"
        case .simulator: "bolt.heart.fill"
        case .articles:  "books.vertical.fill"
        }
    }

    var title: String {
        switch self {
        case .checkIn:   String(localized: "Экспресс-чекин")
        case .analytics: String(localized: "Аналитика триггеров")
        case .avatar:    String(localized: "Аватар прогресса")
        case .squad:     String(localized: "Сквад")
        case .journey:   String(localized: "Мой путь: 45 дней")
        case .simulator: String(localized: "Симулятор тяги")
        case .articles:  String(localized: "Расширенная база знаний")
        }
    }

    /// Две фразы: что делаешь и что из этого получаешь.
    var summary: String {
        switch self {
        case .checkIn:
            String(localized: "За 30 секунд отмечаешь энергию, тягу и триггеры дня. Из этих отметок складывается картина: в какие дни ты сильнее, а в какие уязвимее.")
        case .analytics:
            String(localized: "Показывает, что чаще всего толкает тебя к тяге и срывам, в какое время суток и в какие дни. Напоминание само переносится на час раньше твоего опасного времени.")
        case .avatar:
            String(localized: "Дни без срыва, прочитанные статьи и закрытые челленджи дают опыт. Аватар растёт в ранге вместе с тобой.")
        case .squad:
            String(localized: "Группа до четырёх человек, которые держатся вместе с тобой. Вы видите дни друг друга и поддерживаете в общем чате.")
        case .journey:
            String(localized: "Каждый день — короткий разбор того, что происходит с телом и мозгом на этом этапе. Открывается весь путь, а не только первые дни.")
        case .simulator:
            String(localized: "Готовые сценарии трудных моментов с разбором, что делать, когда накрывает. Разбираешь заранее — и в момент тяги действуешь по плану.")
        case .articles:
            String(localized: "Все статьи о дофамине, привычках и восстановлении, с опорой на исследования. Без Pro открыты только три.")
        }
    }
}
