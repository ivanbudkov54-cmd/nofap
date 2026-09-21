//
//  IntroSurvey.swift
//  NoFap
//
//  Ответы вступительного опроса и разбор их в персональный трек.
//  Хранятся структурно, а не текстом: на кейсы енамов позже обопрутся пуши,
//  Panic Button, ранги и пэйвол. Сопоставление кейса с конкретной командой
//  или оффером живёт в тех фичах, а не здесь — иначе это был бы мёртвый код
//  под то, чего в приложении пока нет.
//

import Foundation

/// Общее у всех вариантов ответа: подпись для экрана и стабильный порядок.
protocol SurveyOption: Hashable, CaseIterable {
    var label: String { get }
}

// MARK: - Варианты ответов

enum UrgeFrequency: String, Codable, CaseIterable, SurveyOption {
    case daily, severalPerWeek, weekly, fewPerMonth

    var label: String {
        switch self {
        case .daily:          String(localized: "Каждый день")
        case .severalPerWeek: String(localized: "Несколько раз в неделю")
        case .weekly:         String(localized: "Примерно раз в неделю")
        case .fewPerMonth:    String(localized: "Несколько раз в месяц")
        }
    }
}

enum HabitYears: String, Codable, CaseIterable, SurveyOption {
    case underYear, oneToThree, threeToSeven, overSeven

    var label: String {
        switch self {
        case .underYear:    String(localized: "Меньше года")
        case .oneToThree:   String(localized: "1–3 года")
        case .threeToSeven: String(localized: "3–7 лет")
        case .overSeven:    String(localized: "Больше 7 лет")
        }
    }
}

enum TriggerState: String, Codable, CaseIterable, SurveyOption {
    case boredom, stress, loneliness, tiredness, feed

    var label: String {
        switch self {
        case .boredom:    String(localized: "Скука")
        case .stress:     String(localized: "Стресс или тревога")
        case .loneliness: String(localized: "Одиночество")
        case .tiredness:  String(localized: "Усталость")
        case .feed:       String(localized: "Залип в ленте")
        }
    }
}

enum Setting: String, Codable, CaseIterable, SurveyOption {
    case inBed, aloneAtHome, atNightComputer, shower

    var label: String {
        switch self {
        case .inBed:           String(localized: "В постели с телефоном")
        case .aloneAtHome:     String(localized: "Один дома вечером")
        case .atNightComputer: String(localized: "За компьютером ночью")
        case .shower:          String(localized: "В душе")
        }
    }
}

enum UrgeWindow: String, Codable, CaseIterable, SurveyOption {
    case morning, afternoon, evening, night, irregular

    var label: String {
        switch self {
        case .morning:   String(localized: "Утром")
        case .afternoon: String(localized: "Днём")
        case .evening:   String(localized: "Вечером")
        case .night:     String(localized: "Ночью")
        case .irregular: String(localized: "По-разному")
        }
    }

    /// Час, с которого начинается опасное окно. У `.irregular` нет своего
    /// времени, но он всё равно отдаёт валидный час: иначе у будущего
    /// планировщика пушей появится лишняя ветка с `nil`.
    var peakHour: Int {
        switch self {
        case .morning:   7
        case .afternoon: 13
        case .evening:   19
        case .night:     23
        case .irregular: 20
        }
    }
}

enum NegativeEffect: String, Codable, CaseIterable, SurveyOption {
    case brainFog, noEnergy, procrastination, selfEsteem, sleep

    var label: String {
        switch self {
        case .brainFog:        String(localized: "Туман в голове")
        case .noEnergy:        String(localized: "Нет энергии")
        case .procrastination: String(localized: "Прокрастинация")
        case .selfEsteem:      String(localized: "Падает самооценка")
        case .sleep:           String(localized: "Сбитый сон")
        }
    }
}

enum DesiredOutcome: String, Codable, CaseIterable, SurveyOption {
    case focus, energy, relationships, selfRespect

    var label: String {
        switch self {
        case .focus:         String(localized: "Фокус в учёбе и зале")
        case .energy:        String(localized: "Энергия")
        case .relationships: String(localized: "Отношения")
        case .selfRespect:   String(localized: "Самоуважение")
        }
    }
}

enum LongestStreak: String, Codable, CaseIterable, SurveyOption {
    case never, upToWeek, upToMonth, overMonth

    var label: String {
        switch self {
        case .never:      String(localized: "Никогда не считал")
        case .upToWeek:   String(localized: "До недели")
        case .upToMonth:  String(localized: "До месяца")
        case .overMonth:  String(localized: "Больше месяца")
        }
    }

    /// Нижняя граница диапазона — с ней сравнивается рекомендованный срок,
    /// чтобы не предложить меньше, чем человек однажды уже прошёл.
    var reachedDays: Int {
        switch self {
        case .never:     0
        case .upToWeek:  7
        case .upToMonth: 30
        case .overMonth: 60
        }
    }
}

enum WhoKnows: String, Codable, CaseIterable, SurveyOption {
    case nobody, onePerson, several

    var label: String {
        switch self {
        case .nobody:    String(localized: "Никто")
        case .onePerson: String(localized: "Один человек")
        case .several:   String(localized: "Несколько человек")
        }
    }
}

// MARK: - Ответы

/// Опционалы и пустые множества — чтобы недозаполненный черновик был
/// представим: человек может свайпнуть назад и передумать.
struct IntroSurveyAnswers: Codable, Equatable {
    var frequency: UrgeFrequency?
    var years: HabitYears?
    var triggers: Set<TriggerState> = []
    var settings: Set<Setting> = []
    var settingsNote: String = ""
    var urgeWindow: UrgeWindow?
    var effects: Set<NegativeEffect> = []
    var effectsNote: String = ""
    var outcomes: Set<DesiredOutcome> = []
    var longestStreak: LongestStreak?
    var whoKnows: WhoKnows?
    var completedAt: Date?
}

extension Set where Element: SurveyOption {
    /// Перечисление в порядке объявления кейсов, а не в порядке множества —
    /// иначе фраза на треке пересобиралась бы по-разному при каждом показе.
    var listed: String {
        Element.allCases
            .filter { self.contains($0) }
            .map(\.label)
            .joined(separator: ", ")
    }
}

// MARK: - Трек

struct PersonalTrack {

    let recommendedGoalDays: Int
    let statements: [String]

    /// Те же пресеты, что и в GoalPicker: рекомендация должна подсветиться
    /// готовой плиткой, а не упасть в поле «своё число».
    private static let ladder = [7, 14, 21, 30, 60, 90]

    static func make(from answers: IntroSurveyAnswers) -> PersonalTrack {
        // Срок считается один раз и передаётся во фразы: раньше `statements`
        // вызывал `recommendedDays` повторно, и два места могли разъехаться.
        let days = recommendedDays(from: answers)
        return PersonalTrack(
            recommendedGoalDays: days,
            statements: statements(from: answers, days: days)
        )
    }

    // MARK: Срок

    private static func recommendedDays(from answers: IntroSurveyAnswers) -> Int {
        let base: Int = switch answers.frequency {
        case .daily:          7
        case .severalPerWeek: 14
        case .weekly:         21
        case .fewPerMonth:    30
        case nil:             21
        }

        var index = ladder.firstIndex(of: base) ?? 2

        // Чем дольше привычка, тем короче первая цель: важно, чтобы первая
        // победа была достижимой, а не «правильной».
        switch answers.years {
        case .underYear: index += 1
        case .overSeven: index -= 1
        default: break
        }
        index = min(max(index, 0), ladder.count - 1)

        // Предложить меньше, чем человек однажды уже прошёл, — значит с
        // порога обесценить его прошлый результат.
        let reached = answers.longestStreak?.reachedDays ?? 0
        if ladder[index] <= reached, let next = ladder.firstIndex(where: { $0 > reached }) {
            index = next
        }

        return ladder[index]
    }

    // MARK: Фразы

    /// Каждая фраза — отражение собственных ответов человека. Свободные поля
    /// цитируются целиком и не разбираются по ключевым словам: это была бы
    /// ровно та поддельная точность, которой продукт избегает.
    ///
    /// Контраста «что теряю / за чем пришёл» здесь нет намеренно: он сильнее
    /// работает двумя колонками на экране, чем фразой среди карточек.
    private static func statements(from answers: IntroSurveyAnswers, days: Int) -> [String] {
        var result: [String] = []

        if let window = answers.urgeWindow {
            if window == .irregular {
                result.append(String(localized: "Ты не привязал тягу ко времени. Значит опорой будет ежедневная отметка, а не один опасный час."))
            } else {
                result.append(String(localized: "Тяга чаще накатывает \(window.label.lowercasedFirst). Слабое место — примерно с \(window.peakHour):00."))
            }
        }

        let note = answers.settingsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            result.append(String(localized: "Ты сам назвал обстановку: «\(String(note.prefix(90)))». Это триггер, а не слабость."))
        } else if !answers.settings.isEmpty {
            result.append(String(localized: "Чаще всего это случается тут: \(answers.settings.listed.lowercasedFirst)."))
        }

        result.append(String(localized: "Начни с \(days) дней — не потому что это правильный срок, а потому что его реально пройти. Дальше поднимешь сам."))

        return result
    }
}

private extension String {
    /// Подписи вариантов написаны с заглавной — внутри фразы они должны
    /// становиться строчными, иначе Предложение Выглядит Так.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
