//
//  ManifestManager.swift
//  NoFap
//
//  «Договор с собой» из опроса: что человек чувствует после срыва, что уже
//  потерял и кем станет через 5 лет. Показывается в дневнике и в SOS.
//

import Foundation

struct UserPainManifest: Codable, Equatable {
    var postRelapseFeeling: [String]
    var pastYearLosses: [String]
    var fiveYearFutureVision: String
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
            "Если я сдамся, через 5 лет я стану: \(fiveYearFutureVision)"
        ]
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
        return "Ты лично написал это в первый день: после срыва \(awaits). Ты уже отдал этой привычке \(loss). Неужели ты готов добровольно стать тем, кого описал через 5 лет?"
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
        future: String,
        notes: String?,
        journal: JournalManager
    ) {
        let created = currentManifest?.createdAt ?? Date()
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let manifest = UserPainManifest(
            postRelapseFeeling: postRelapse.filter { !$0.isEmpty },
            pastYearLosses: losses.filter { !$0.isEmpty },
            fiveYearFutureVision: future,
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
