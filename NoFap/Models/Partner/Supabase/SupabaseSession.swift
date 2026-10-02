//
//  SupabaseSession.swift
//  NoFap
//
//  Анонимный вход в Supabase Auth через REST: без почты и пароля,
//  приложение само получает случайный идентификатор. Refresh-токен лежит
//  в Keychain, access-токен — только в памяти.
//

import Foundation

enum SupabaseAuthError: Error {
    /// Анонимный вход не включён в проекте или неверные ключи.
    case notConfigured
}

@MainActor
final class SupabaseSession {

    /// Одна сессия на всё приложение. Refresh-токен в Supabase одноразовый:
    /// две независимые сессии (напарник, сквад) обновляли бы его наперегонки,
    /// проигравшая получила бы отказ и завела новый анонимный аккаунт.
    static let shared = SupabaseSession()

    private(set) var uid: String?
    private var accessToken: String?
    private var expiresAt = Date.distantPast

    /// Один общий запрос на токен: два одновременных вызова иначе завели бы
    /// два разных анонимных аккаунта, а refresh-токен в Supabase одноразовый.
    private var pending: Task<String, Error>?

    private enum Key {
        static let uid = "supabase.uid"
        static let refreshToken = "supabase.refreshToken"
    }

    private init() {
        uid = Keychain.read(Key.uid)
    }

    func userID() async throws -> String {
        _ = try await token()
        guard let uid else { throw SupabaseAuthError.notConfigured }
        return uid
    }

    func token() async throws -> String {
        if let accessToken, expiresAt > Date().addingTimeInterval(60) { return accessToken }
        if let pending { return try await pending.value }

        let task = Task { try await obtainToken() }
        pending = task
        defer { pending = nil }
        return try await task.value
    }

    /// После удаления аккаунта: следующий запрос заведёт нового анонимного
    /// пользователя, старый идентификатор больше нигде не используется.
    func signOut() {
        pending = nil
        accessToken = nil
        expiresAt = .distantPast
        uid = nil
        Keychain.write(Key.uid, nil)
        Keychain.write(Key.refreshToken, nil)
    }

    /// Сервер ответил 401 — токен отозван раньше срока.
    func invalidate() {
        accessToken = nil
        expiresAt = .distantPast
    }

    // MARK: - Внутреннее

    private enum RefreshError: Error { case rejected }

    private func obtainToken() async throws -> String {
        if let refresh = Keychain.read(Key.refreshToken) {
            do {
                return try await exchange(path: "token?grant_type=refresh_token",
                                          body: ["refresh_token": refresh])
            } catch RefreshError.rejected {
                // Только явный отказ сервера ведёт к новому аккаунту. Сетевая
                // ошибка пробрасывается дальше: заводить новый идентификатор
                // из-за пропавшего Wi-Fi значило бы молча разорвать связь.
            }
        }
        return try await exchange(path: "signup", body: [:])
    }

    /// signup без почты = анонимный вход; token?grant_type=refresh_token —
    /// продление. Ответ у обоих одинаковый.
    private func exchange(path: String, body: [String: Any]) async throws -> String {
        var request = URLRequest(url: URL(string: "\(SupabaseConfig.url)/auth/v1/\(path)")!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard status == 200 else {
            let isRefresh = path.hasPrefix("token")
            // 4xx на продление — токен протух или уже использован; на
            // регистрацию — анонимный вход выключен. 5xx — временно.
            if (400..<500).contains(status) {
                throw isRefresh ? RefreshError.rejected : SupabaseAuthError.notConfigured
            }
            throw URLError(.badServerResponse)
        }

        guard let token = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String else {
            throw SupabaseAuthError.notConfigured
        }

        let seconds = (json["expires_in"] as? Double) ?? 3600
        accessToken = token
        expiresAt = Date().addingTimeInterval(seconds)
        uid = id.lowercased()
        Keychain.write(Key.uid, uid)
        Keychain.write(Key.refreshToken, refresh)
        return token
    }
}
