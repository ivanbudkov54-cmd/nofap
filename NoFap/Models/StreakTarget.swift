//
//  StreakTarget.swift
//  NoFap
//

import SwiftUI

enum StreakTarget: Int, CaseIterable, Identifiable {
    case breakout = 7
    case clarity = 21
    case reset = 45
    case sovereign = 90

    var id: Int { rawValue }
    var days: Int { rawValue }

    var title: String {
        switch self {
        case .breakout: "Разрыв цепи"
        case .clarity: "Ясный фокус"
        case .reset: "Глубокая перезагрузка"
        case .sovereign: "Новая норма / Титан"
        }
    }

    var badge: String {
        switch self {
        case .breakout: "Тестостероновый пик"
        case .clarity: "Регенерация дофамина"
        case .reset: "Калибровка рецепторов"
        case .sovereign: "Структурная нейропластичность"
        }
    }

    var bodyEffect: String {
        switch self {
        case .breakout:
            "Уровень свободного тестостерона достигает пика в 145.7% (исследование Чжэцзянского университета). Взрыв физической энергии и выносливости."
        case .clarity:
            "Восстанавливается плотность D2-рецепторов дофамина. Нормализуется фаза глубокого сна (REM)."
        case .reset:
            "Повышается чувствительность андрогенных рецепторов. Угасает эффект Кулиджа — возвращается здоровое влечение к реальным девушкам."
        case .sovereign:
            "Дофаминовая система стабилизируется на эволюционной норме. Высокий, ровный уровень энергии с утра до вечера."
        }
    }

    var mindEffect: String {
        switch self {
        case .breakout:
            "Разрушается компульсивная петля первых 72 часов. Снижается пролактиновая сонливость."
        case .clarity:
            "Рассеивается «туман в голове». Простые вещи (еда, спорт, хобби) снова приносят естественный кайф без гиперстимуляции."
        case .reset:
            "Уходит социальная тревожность. Голос становится увереннее и плотнее, взгляд держится расслабленно и прямо."
        case .sovereign:
            "Префронтальная кора формирует прочные синаптические связи. Контроль импульсов становится твоей естественной природой."
        }
    }

    var highlightQuote: String {
        switch self {
        case .breakout: "Сбить острую тягу и вернуть физическую силу."
        case .clarity: "Вернуть ясность ума и контроль над вниманием."
        case .reset: "Преодолеть «flatline» и восстановить мужской тонус."
        case .sovereign: "Закрепить новую личность и стать хозяином своего разума."
        }
    }

    var dayBadge: String {
        switch self {
        case .breakout: "7 ДНЕЙ"
        case .clarity: "21 ДЕНЬ"
        case .reset: "45 ДНЕЙ"
        case .sovereign: "90 ДНЕЙ"
        }
    }

    var tint: Color {
        switch self {
        case .breakout: Color(hex: 0xF0BC4F)
        case .clarity: Color(hex: 0x5BA8FF)
        case .reset: Color(hex: 0xA78BFA)
        case .sovereign: Color(hex: 0x3DDC97)
        }
    }
}
