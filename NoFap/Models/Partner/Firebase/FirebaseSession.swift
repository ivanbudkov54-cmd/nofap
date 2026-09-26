//
//  FirebaseSession.swift
//  NoFap
//
//  Анонимный вход в Firebase через REST: без почты и пароля, приложение
//  само получает случайный идентификатор. Refresh-токен лежит в Keychain,
//  короткоживущий ID-токен — только в памяти.
//

import Foundation
import Security

enum FirebaseAuthError: Error {
    /// Анонимный вход не включён в консоли или неверный ключ проекта.
    case notConfigured
}

@MainActor
final class FirebaseSession {

    private(set) var uid: String?
    private var idToken: String?
    private var expiresAt = Date.distantPast

    /// Один общий запрос на токен: два одновременных вызова иначе завели бы
    /// два разных анонимных аккаунта.
    private var pending: Task<String, Error>?

    init() {
        uid = Keychain.read(Key.uid)
    }

    func userID() async throws -> String {
        _ = try await token()
        guard let uid else { throw FirebaseAuthError.notConfigured }
        return uid
    }

    func token() async throws -> String {
        if let idToken, expiresAt > Date().addingTimeInterval(60) { return idToken }
        if let pending { return try await pending.value }

        let task = Task { try await obtainToken() }
        pending = task
        defer { pending = nil }
        return try await task.value
    }

    /// Сервер ответил 401 — токен отозван раньше срока.
    func invalidate() {
        idToken = nil
        expiresAt = .distantPast
    }

    /// Удаляет анонимный аккаунт. Следующий `token()` заведёт новый с другим
    /// идентификатором — так разрыв связи отзывает у бывшего напарника доступ.
    func deleteAccount() async {
        if let token = try? await token() {
            _ = try? await post("https://identitytoolkit.googleapis.com/v1/accounts:delete",
                                json: ["idToken": token])
        }
        Keychain.write(Key.uid, nil)
        Keychain.write(Key.refreshToken, nil)
        uid = nil
        invalidate()
    }

    // MARK: - Внутреннее

    private enum Key {
        static let uid = "firebase.uid"
        static let refreshToken = "firebase.refreshToken"
    }

    private func obtainToken() async throws -> String {
        if let refresh = Keychain.read(Key.refreshToken) {
            do {
                return try await refreshToken(refresh)
            } catch RefreshError.rejected {
                // Только явный отказ сервера ведёт к новому аккаунту. Сетевая
                // ошибка пробрасывается дальше: заводить новый идентификатор
                // из-за пропавшего Wi-Fi значило бы молча разорвать связь.
            }
        }
        return try await signUp()
    }

    private enum RefreshError: Error { case rejected }

    private func signUp() async throws -> String {
        let (status, body) = try await post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signUp",
            json: ["returnSecureToken": true]
        )
        guard status == 200,
              let token = body["idToken"] as? String,
              let refresh = body["refreshToken"] as? String,
              let localID = body["localId"] as? String else {
            throw FirebaseAuthError.notConfigured
        }
        store(token: token, refresh: refresh, uid: localID, expiresIn: body["expiresIn"])
        return token
    }

    private func refreshToken(_ refresh: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [.init(name: "grant_type", value: "refresh_token"),
                           .init(name: "refresh_token", value: refresh)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        // 400 — токен протух, аккаунт удалён или отключён; 5xx — временно.
        guard status == 200 else {
            if status == 400 { throw RefreshError.rejected }
            throw URLError(.badServerResponse)
        }
        guard let token = body["id_token"] as? String,
              let newRefresh = body["refresh_token"] as? String,
              let userID = body["user_id"] as? String else {
            throw RefreshError.rejected
        }
        store(token: token, refresh: newRefresh, uid: userID, expiresIn: body["expires_in"])
        return token
    }

    private func store(token: String, refresh: String, uid: String, expiresIn: Any?) {
        let seconds = (expiresIn as? String).flatMap(Double.init) ?? 3600
        idToken = token
        expiresAt = Date().addingTimeInterval(seconds)
        self.uid = uid
        Keychain.write(Key.uid, uid)
        Keychain.write(Key.refreshToken, refresh)
    }

    private func post(_ endpoint: String, json: [String: Any]) async throws -> (Int, [String: Any]) {
        var request = URLRequest(url: URL(string: "\(endpoint)?key=\(FirebaseConfig.apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (status, body)
    }
}

/// Минимальная обёртка над Keychain — только строки под своим service.
private enum Keychain {

    private static let service = "Albert.lvan.NoFap.partner"

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
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
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
