//
//  ManifestManager.swift
//  NoFap
//
//  «Договор с собой» из опроса: что человек чувствует после срыва, что уже
//  потерял и кем хочет стать через год без срывов. Показывается в дневнике
//  и в SOS.
//

import Foundation

struct UserPainManifest: Codable, Equatable {
    var postRelapseFeeling: [String]
    var pastYearLosses: [String]
    /// Прежний вопрос «кем станешь через 5 лет, если сдашься». Новые договоры
    /// его не заполняют; у старых он остаётся, пока человек сам не сотрёт.
    var fiveYearFutureVision: String
    /// Кем человек видит себя через год без срывов: цель, а не страшилка.
    var yearVision: String?
    var customNotes: String?
    var createdAt: Date

    var journalText: String {
        let feelings = postRelapseFeeling.joined(separator: ", ")
        let losses = pastYearLosses.joined(separator: ", ")
        var lines = [
            "#Манифест",
            "📍 Точка А: Почему я здесь",
            "",
            "После срыва я чувствую: \(feelings)",
            "Я уже потерял: \(losses)",
        ]
        if let yearVision, !yearVision.isEmpty {
            lines.append("Через год без срывов я стану: \(yearVision)")
        }
        if !fiveYearFutureVision.isEmpty {
            lines.append("Если я сдамся, через 5 лет я стану: \(fiveYearFutureVision)")
        }
        if let customNotes, !customNotes.isEmpty {
            lines.append("")
            lines.append(customNotes)
        }
        return lines.joined(separator: "\n")
    }

    /// Варианты опроса начинаются с эмодзи и заглавной — посреди фразы
    /// это читается как сбой, поэтому в цитаты они идут очищенными.
    var sosQuote: String {
        let feelings = postRelapseFeeling.prefix(2).map(Self.phrase)
        let awaits = switch feelings.count {
        case 0: "тебя ждёт пустота"
        case 1: "тебя ждёт \(feelings[0])"
        default: "тебя ждут \(feelings[0]) и \(feelings[1])"
        }
        let loss = pastYearLosses.first.map(Self.accusative) ?? "то, что уже нельзя вернуть"
        let quote = "Ты лично написал это в первый день: после срыва \(awaits). Ты уже отдал этой привычке \(loss)."
        if let yearVision, !yearVision.isEmpty {
            // Слова человека — в кавычках как есть: падеж своего текста
            // не угадать, а точка в конце задвоилась бы с нашей.
            let vision = yearVision.trimmingCharacters(in: CharacterSet(charactersIn: ".!… ").union(.whitespacesAndNewlines))
            return quote + " Через год без срывов ты видишь себя так: «\(vision)». Не меняй это на пять минут."
        }
        if !fiveYearFutureVision.isEmpty {
            return quote + " Неужели ты готов добровольно стать тем, кого описал через 5 лет?"
        }
        return quote
    }

    /// Ответы для карточки: без эмодзи вариантов, через запятую, с заглавной.
    static func list(_ options: [String]) -> String {
        let text = options.map(phrase).joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Короткая версия для экрана блокировки: места под подзаголовок там мало.
    var shieldQuote: String {
        let feeling = postRelapseFeeling.first.map(Self.phrase) ?? "пустота"
        let loss = pastYearLosses.first.map(Self.accusative) ?? "то, что уже не вернуть"
        return "Ты сам написал: после срыва — \(feeling). Ты уже отдал этому \(loss). Не сейчас."
    }

    /// «📉 Резкая физическая слабость» → «резкая физическая слабость».
    private static func phrase(_ option: String) -> String {
        let text = option
            .drop { !$0.isLetter && !$0.isNumber }
            .trimmingCharacters(in: .whitespaces)
        return text.prefix(1).lowercased() + text.dropFirst()
    }

    /// «Отдал этой привычке …» требует винительного падежа, а варианты
    /// опроса записаны в именительном. Своё, введённое руками, — как есть.
    private static func accusative(_ option: String) -> String {
        let nominative = phrase(option)
        let forms = [
            "драйв и энергия для бизнеса / учебы": "драйв и энергию для бизнеса и учёбы",
            "тестостерон, выносливость и форма": "тестостерон, выносливость и форму",
        ]
        return forms[nominative] ?? nominative
    }
}

@MainActor
@Observable
final class ManifestManager {
    private static let storageKey = "savedUserManifestJSON"

    private(set) var currentManifest: UserPainManifest?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.storageKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(UserPainManifest.self, from: data) {
            currentManifest = decoded
        }
    }

    func saveManifest(
        postRelapse: [String],
        losses: [String],
        vision: String,
        legacyFuture: String = "",
        notes: String?,
        journal: JournalManager
    ) {
        let created = currentManifest?.createdAt ?? Date()
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let manifest = UserPainManifest(
            postRelapseFeeling: postRelapse.filter { !$0.isEmpty },
            pastYearLosses: losses.filter { !$0.isEmpty },
            fiveYearFutureVision: legacyFuture.trimmingCharacters(in: .whitespacesAndNewlines),
            yearVision: vision.trimmingCharacters(in: .whitespacesAndNewlines),
            customNotes: trimmedNotes?.isEmpty == false ? trimmedNotes : nil,
            createdAt: created
        )
        currentManifest = manifest
        if let data = try? JSONEncoder().encode(manifest),
           let raw = String(data: data, encoding: .utf8) {
            defaults.set(raw, forKey: Self.storageKey)
        }
        journal.upsertManifest(manifest.journalText, on: created)
    }
}
