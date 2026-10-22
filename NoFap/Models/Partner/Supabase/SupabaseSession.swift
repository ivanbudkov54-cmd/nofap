//
//  SupabaseSession.swift
//  NoFap
//
//  Анонимный вход в Supabase Auth через REST: без почты и пароля,
//  приложение само получает случайный идентификатор. Refresh-токен лежит
//  в Keychain, access-токен — только в памяти.
//

import Foundation

enum EmailLinkError: LocalizedError {
    case invalidCode
    case tooManyAttempts
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCode:     "Неверный код. Проверьте письмо и введите его ещё раз."
        case .tooManyAttempts: "Слишком много попыток. Подождите минуту и запросите код снова."
        case .network:         "Нет подключения к сети. Проверьте интернет и попробуйте ещё раз."
        }
    }

    static func from(status: Int, body: Data) -> EmailLinkError {
        let text = String(decoding: body, as: UTF8.self).lowercased()
        if status == 429 || text.contains("rate") || text.contains("over_email") || text.contains("too many") {
            return .tooManyAttempts
        }
        return .network
    }
}

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
        // Аккаунты, заведённые до синхронизации, переезжают в связку iCloud.
        Keychain.moveToICloud([Key.uid, Key.refreshToken])
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

    // MARK: - Вход по почте

    /// Код из 6 цифр на почту. Если такого пользователя нет — Supabase его заведёт.
    func sendEmailCode(to email: String) async throws {
        var request = URLRequest(url: URL(string: "\(SupabaseConfig.url)/auth/v1/otp")!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "create_user": true])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw EmailLinkError.from(status: status, body: data)
        }
    }

    /// Подтверждает код и переключает приложение на аккаунт с этой почтой.
    /// Анонимный аккаунт остаётся на сервере, данные приложения переезжают
    /// через копию прогресса и синхронизацию.
    @discardableResult
    func verifyEmailCode(email: String, code: String) async throws -> String {
        do {
            _ = try await exchange(path: "verify", body: ["email": email, "token": code, "type": "email"])
        } catch SupabaseAuthError.notConfigured {
            throw EmailLinkError.invalidCode
        } catch {
            throw EmailLinkError.network
        }
        guard let uid else { throw EmailLinkError.network }
        return uid
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
                //
                // Токен одноразовый и общий для телефонов с одним Apple ID:
                // другой телефон мог уже обменять его и положить в связку
                // свежий. Пробуем свежий, прежде чем сдаться.
                if let fresher = Keychain.read(Key.refreshToken), fresher != refresh {
                    try? await Task.sleep(for: .seconds(1))
                    if let token = try? await exchange(path: "token?grant_type=refresh_token",
                                                       body: ["refresh_token": fresher]) {
                        return token
                    }
                }
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
