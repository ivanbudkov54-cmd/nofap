//
//  Keychain.swift
//  NoFap
//
//  Минимальная обёртка над Keychain — только строки под своим service.
//  Токены входа хранятся здесь, а не в UserDefaults: Keychain шифруется
//  и не попадает в незашифрованные бэкапы.
//
//  Записи синхронизируются через связку ключей iCloud: на новом iPhone с
//  тем же Apple ID приложение подхватывает тот же аккаунт, и прогресс с
//  подпиской не теряются. Связка шифруется сквозным ключом — Apple её не
//  читает. Если у человека она выключена, запись просто остаётся на
//  телефоне, как раньше.
//

import Foundation
import Security

enum Keychain {

    private static let service = "Albert.lvan.NoFap.partner"

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            // И старые записи «только на этом телефоне», и синхронизируемые.
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // «ThisDeviceOnly» с синхронизацией несовместим.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Переносит записи, сделанные до синхронизации, в связку ключей iCloud.
    static func moveToICloud(_ keys: [String]) {
        for key in keys {
            if let value = read(key) { write(key, value) }
        }
    }
}
