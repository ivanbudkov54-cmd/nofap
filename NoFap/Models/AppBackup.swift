//
//  AppBackup.swift
//  NoFap
//
//  Резервная копия всего, что приложение хранит в UserDefaults, — в
//  таблице app_backups (supabase/05_app_backup.sql). Новые фичи попадают в
//  копию сами: исключаются только системные и служебные ключи.
//
//  Главное правило: пустой телефон не должен затереть копию. Отправлять
//  можно только после того, как сервер ответил, есть ли у аккаунта копия, —
//  и, если есть, после восстановления или явного «начать заново».
//

import Foundation
import UIKit
import os

@MainActor
@Observable
final class AppBackup {

    struct Found: Equatable {
        let payload: Data
        let savedAt: Date
    }

    /// Копия нашлась, когда приложением уже пользуются, — RestoreGate
    /// спрашивает, восстановить ли её.
    var offer: Found?

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "backup")

    private let client = SupabaseClient(session: .shared)
    private let defaults: UserDefaults
    private var lastUpload = Date.distantPast

    private enum Key {
        /// Сервер ответил про копию этого аккаунта — отправлять можно.
        static let checkedFor = "backup.checkedFor"
        /// После восстановления: защиту Screen Time надо включить заново —
        /// разрешение выдаётся телефону, а не аккаунту.
        static let needsProtection = "backup.needsProtection"
    }

    /// Восстановили копию — ContentView заново включает блокировку.
    var needsProtection: Bool {
        get { defaults.bool(forKey: Key.needsProtection) }
        set { defaults.set(newValue, forKey: Key.needsProtection) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Проверка и восстановление

    enum CheckResult { case restoreNow(Found), nothing, unknown }

    /// Есть ли на сервере копия этого аккаунта. `unknown` — нет сети или
    /// сервера: отправлять копии нельзя, спросим в другой раз.
    func check() async -> CheckResult {
        guard SupabaseConfig.isConfigured,
              let uid = try? await SupabaseSession.shared.userID() else { return .unknown }
        if defaults.string(forKey: Key.checkedFor) == uid { return .nothing }

        let rows: [Row]
        do {
            rows = try await client.select("app_backups", [("user_id", "eq.\(uid)")],
                                           columns: "payload,updated_at")
        } catch {
            Self.log.error("check failed: \(error.localizedDescription)")
            return .unknown
        }
        guard let row = rows.first, let payload = Data(base64Encoded: row.payload) else {
            markChecked(uid)
            return .nothing
        }
        return .restoreNow(Found(payload: payload, savedAt: row.updatedAt))
    }

    /// Записывает копию поверх текущих данных. Менеджеры читают UserDefaults
    /// при создании — после этого RestoreGate пересоздаёт их.
    func restore(_ found: Found) async {
        guard let values = try? PropertyListSerialization.propertyList(from: found.payload, format: nil)
                as? [String: Any] else { return }
        for key in ownKeys() { defaults.removeObject(forKey: key) }
        for (key, value) in values where Self.isBackedUp(key) {
            defaults.set(value, forKey: key)
        }
        needsProtection = true
        if let uid = try? await SupabaseSession.shared.userID() { markChecked(uid) }
        Self.log.info("restored \(values.count) keys")
    }

    /// «Начать заново»: копия на сервере будет перезаписана текущими данными.
    func decline() async {
        offer = nil
        if let uid = try? await SupabaseSession.shared.userID() { markChecked(uid) }
        await upload(force: true)
    }

    private func markChecked(_ uid: String) {
        defaults.set(uid, forKey: Key.checkedFor)
    }

    // MARK: - Отправка

    /// Не чаще раза в минуту, если не `force` (уход в фон).
    func upload(force: Bool = false) async {
        guard SupabaseConfig.isConfigured,
              force || Date().timeIntervalSince(lastUpload) > 60,
              let uid = try? await SupabaseSession.shared.userID(),
              defaults.string(forKey: Key.checkedFor) == uid else { return }

        var values: [String: Any] = [:]
        for key in ownKeys() { values[key] = defaults.object(forKey: key) }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: values,
                                                             format: .binary, options: 0) else { return }
        lastUpload = Date()
        // При уходе в фон iOS даёт закончить отправку, а не замораживает её.
        let background = UIApplication.shared.beginBackgroundTask(withName: "backup")
        defer { UIApplication.shared.endBackgroundTask(background) }
        do {
            try await client.insert("app_backups", [[
                "user_id": uid,
                "payload": data.base64EncodedString(),
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                "updated_at": PostgresTime.string(from: Date())
            ]], upsert: true)
        } catch {
            lastUpload = .distantPast
            Self.log.error("upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Какие ключи

    /// Ключи самого приложения, без системных.
    private func ownKeys() -> [String] {
        let domain = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        return domain.keys.filter(Self.isBackedUp)
    }

    private static let skippedPrefixes = [
        "Apple", "NS", "com.apple", "AK", "PK", "SK", "WebKit", "INNext", "MSV",
        "backup.",          // служебное этой копии
        "fake."             // локальные заглушки напарника и сквада
    ]
    private static let skippedKeys: Set<String> = [
        "premiumOverride", "webCheckoutOverride",   // отладка
        "testerPro",                                // Pro для своих в TestFlight
        "knowledgeArticlesCache"                    // скачивается заново
    ]

    private static func isBackedUp(_ key: String) -> Bool {
        !skippedKeys.contains(key) && !skippedPrefixes.contains { key.hasPrefix($0) }
    }

    private struct Row: Decodable {
        let payload: String
        let updatedAt: Date
    }
}
