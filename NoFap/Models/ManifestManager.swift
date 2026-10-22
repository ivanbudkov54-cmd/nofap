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

    var sosQuote: String {
        let first = postRelapseFeeling.first ?? "пустоту"
        let second = postRelapseFeeling.dropFirst().first ?? first
        let loss = pastYearLosses.first ?? "то, что уже нельзя вернуть"
        return "Ты лично написал это в первый день: после срыва тебя ждет \(first) и \(second). Ты уже отдал этой привычке \(loss). Неужели ты готов добровольно стать тем, кого описал через 5 лет?"
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
