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
    case expired
    case tooManyAttempts
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCode:     "Неверная ссылка. Запросите новую из приложения и не открывайте её в браузере."
        case .expired:         "Ссылка уже использована или истекла. Запросите новую и вставьте её сюда, не открывая."
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

    /// Куда GoTrue вернёт сессию после клика по magic link.
    /// Должен быть в Redirect URLs: `https://spartan-pro.ru/auth.html` и `nofap://**`.
    static let magicLinkRedirect = "https://spartan-pro.ru/auth.html"

    static func isMagicLink(_ url: URL) -> Bool {
        url.scheme == "nofap" && url.host()?.lowercased() == "auth"
    }

    /// Код из 6 цифр на почту. Если такого пользователя нет — Supabase его заведёт.
    /// На Free-проекте шаблон письма — ссылка, не цифры: после клика
    /// сессия приходит сюда через `nofap://auth`.
    func sendEmailCode(to email: String) async throws {
        // redirect_to должен быть в Allow List проекта. Иначе GoTrue
        // подставляет Site URL (по умолчанию localhost) — браузер
        // открывает мёртвую ссылку вместо письма с кодом.
        var components = URLComponents(string: "\(SupabaseConfig.url)/auth/v1/otp")!
        components.queryItems = [
            URLQueryItem(name: "redirect_to", value: Self.magicLinkRedirect),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "create_user": true,
        ])
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

    /// Safari теряет `#access_token` у `nofap://`, поэтому страница
    /// `auth.html` кладёт токены в query. Ссылку из письма можно и вставить.
    @discardableResult
    func consumeVerifyURL(_ url: URL) async throws -> String? {
        if Self.isMagicLink(url) { return try await applyMagicLink(url) }
        let host = url.host()?.lowercased() ?? ""
        if host.contains("spartan-pro.ru"), url.path.contains("auth") {
            return try await applyMagicLink(url)
        }
        guard host.contains("supabase.co"), url.path.contains("/auth/v1/verify") else {
            throw EmailLinkError.invalidCode
        }
        let catcher = MagicLinkRedirectCatcher()
        let session = URLSession(configuration: .ephemeral, delegate: catcher, delegateQueue: nil)
        do {
            _ = try await session.data(for: URLRequest(url: url))
        } catch {
            if catcher.location == nil { throw EmailLinkError.network }
        }
        guard let location = catcher.location else { throw EmailLinkError.network }
        return try await applyMagicLink(location)
    }

    /// Сессия из редиректа (`nofap://auth?access_token=` или `#access_token=`).
    @discardableResult
    func applyMagicLink(_ url: URL) async throws -> String? {
        let pairs = Self.parameters(from: url)
        if pairs["error_code"] == "otp_expired" || pairs["error"] == "access_denied" {
            throw EmailLinkError.expired
        }
        if pairs["error"] != nil || pairs["error_code"] != nil {
            throw EmailLinkError.invalidCode
        }
        guard let access = pairs["access_token"], let refresh = pairs["refresh_token"] else {
            throw EmailLinkError.invalidCode
        }
        var request = URLRequest(url: URL(string: "\(SupabaseConfig.url)/auth/v1/user")!)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200, let id = json["id"] as? String else {
            throw EmailLinkError.network
        }
        let seconds = Double(pairs["expires_in"] ?? "") ?? 3600
        accessToken = access
        expiresAt = Date().addingTimeInterval(seconds)
        uid = id.lowercased()
        Keychain.write(Key.uid, uid)
        Keychain.write(Key.refreshToken, refresh)
        return json["email"] as? String
    }

    private static func parameters(from url: URL) -> [String: String] {
        var pairs: [String: String] = [:]
        let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)
        for item in encoded?.queryItems ?? [] {
            if let value = item.value { pairs[item.name] = value }
        }
        // `URLComponents.queryItems` пустой, если токены пришли как
        // `nofap://auth?access_token=…` без стандартного host/path.
        if pairs.isEmpty, let query = url.query {
            Self.merge(query, into: &pairs)
        }
        let fragment = url.fragment ?? encoded?.fragment
        if let fragment { Self.merge(fragment, into: &pairs) }
        return pairs
    }

    private static func merge(_ raw: String, into pairs: inout [String: String]) {
        for piece in raw.split(separator: "&") {
            let parts = piece.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            pairs[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
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

/// Не ходим по `nofap://` редиректу: URLSession его не откроет, а Safari
/// на симуляторе выкидывает фрагмент с токенами.
private final class MagicLinkRedirectCatcher: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated(unsafe) var location: URL?

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let header = response.value(forHTTPHeaderField: "Location") {
            location = URL(string: header)
        }
        completionHandler(nil)
    }
}
