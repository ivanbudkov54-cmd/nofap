//
//  SupabaseClient.swift
//  NoFap
//
//  Тонкий клиент Auth + PostgREST. Сессия лежит в Keychain, не в UserDefaults:
//  JWT не должен оставаться в бэкапе plist. Ошибки сети не пробрасываются
//  наружу как крэш — вызывающий код получает SupabaseError.
//

import Foundation
import Security

func supabaseLog(_ message: String) {
    print("[Supabase] \(message)")
    fflush(stdout)
}

struct SupabaseSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: UUID
}

enum SupabaseError: LocalizedError {
    case notConfigured
    case notSignedIn
    case offline
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Сервер ещё не подключён. Данные остаются на устройстве."
        case .notSignedIn:
            "Сессия не найдена. Откройте приложение ещё раз при наличии сети."
        case .offline:
            "Нет подключения к сети. Запись сохранена локально"
        case .server(let message):
            message
        }
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }
}

enum KeychainStore {
    private static let service = "Albert.lvan.NoFap.supabase"
    private static let account = "session"

    static func save(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct KnowledgeArticle: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let tabType: String
    let title: String
    let description: String?
    let content: String?
    let orderIndex: Int
}

struct RemoteProfile: Decodable {
    let currentStreakDays: Int
    let bestStreakDays: Int
    let streakStartDate: Date?
    let lastRelapseAt: Date?
    let lastStreakFreezeDate: Date?
}

struct RemoteJournalRow: Decodable {
    let id: UUID
    let moodScore: Int?
    let urgeScore: Int?
    let promptText: String?
    let reflectionNote: String?
    let createdAt: Date
}

@MainActor
final class SupabaseClient {
    private let sessionBox = SessionBox()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: raw) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: raw)
        }
        return decoder
    }()

    func currentUserId() -> UUID? {
        sessionBox.session?.userId
    }

    func ensureSession() async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        if let session = sessionBox.session, session.expiresAt > Date().addingTimeInterval(60) {
            supabaseLog("session restored user_id=\(session.userId.uuidString)")
            return
        }
        if sessionBox.session != nil {
            do {
                try await refresh()
                return
            } catch {
                supabaseLog("token refresh failed, starting a new session")
                sessionBox.session = nil
            }
        }
        try await signInAnonymously()
    }

    func signInAnonymously() async throws {
        let data = try await auth(path: "signup", method: "POST", body: Data("{}".utf8), authorized: false)
        sessionBox.session = try decodeSession(data)
        supabaseLog("anonymous session user_id=\(sessionBox.session?.userId.uuidString ?? "nil")")
    }

    /// Сначала строки пользователя, затем auth.users. Сессия и Keychain
    /// очищаются только после успешного ответа, чтобы повтор мог дойти до сервера.
    func deleteAccount() async throws {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        let id = userId.uuidString
        _ = try await rest(path: "journal_entries?user_id=eq.\(id)", method: "DELETE", body: nil)
        _ = try await rest(path: "relapses?user_id=eq.\(id)", method: "DELETE", body: nil)
        _ = try await rest(path: "profiles?id=eq.\(id)", method: "DELETE", body: nil)
        _ = try await rest(path: "rpc/delete_own_account", method: "POST", body: Data("{}".utf8))
        sessionBox.session = nil
        supabaseLog("account deleted, session cleared user_id=\(id)")
    }

    func ensureInviteCode() async throws -> UserProfile {
        try await ensureInviteCodeDirect()
    }

    func fetchCurrentBuddy() async throws -> UserProfile? {
        let me = try await loadOwnProfile()
        guard let buddyId = me?.buddyId else { return nil }
        return try await loadProfile(id: buddyId)
    }

    func sendBuddyInvite() async throws -> String {
        let data = try await rpc("create_buddy_invite", body: Data("{}".utf8))
        return try decoder.decode(String.self, from: data)
    }

    func acceptBuddyInvite(code: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["invite_code": code])
        _ = try await rpc("accept_buddy_invite", body: body)
    }

    func lookupBuddy(code: String) async throws -> UserProfile {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? code
        let rows = try await profileRows("profiles?invite_code=eq.\(encoded)&select=\(Self.profileSelect)&limit=1")
        if let row = rows.first { return row.asUser }
        let body = try JSONSerialization.data(withJSONObject: ["target_code": code])
        let data = try await rpc("lookup_buddy_by_code", body: body)
        if Self.isNull(data) { throw BuddyError.userNotFound }
        return try decoder.decode(UserProfile.self, from: data)
    }

    func pairWithBuddy(code: String) async throws -> UserProfile {
        let body = try JSONSerialization.data(withJSONObject: ["target_code": code])
        let data = try await rpc("handle_pair_buddies", body: body)
        if Self.isNull(data) { throw BuddyError.userNotFound }
        return try decoder.decode(UserProfile.self, from: data)
    }

    func pingBuddySOS() async throws {
        _ = try await rpc("send_sos_push", body: Data("{}".utf8))
    }

    func fetchMessages() async throws -> [ChatMessage] {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        let data = try await restData(
            path: "buddy_messages?or=(sender_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString))&order=created_at.asc",
            method: "GET",
            body: nil
        )
        return try decoder.decode([ChatMessage].self, from: data)
    }

    func sendBuddyMessage(to receiver: UUID, text: String) async throws {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        let body = try JSONSerialization.data(withJSONObject: [
            "sender_id": userId.uuidString,
            "receiver_id": receiver.uuidString,
            "text": text
        ])
        _ = try await rest(path: "buddy_messages", method: "POST", body: body)
    }

    func fetchUserSquad() async throws -> SquadModel? {
        do {
            let data = try await rpc("fetch_user_squad", body: Data("{}".utf8))
            if Self.isNull(data) { return nil }
            return try decoder.decode(SquadModel.self, from: data)
        } catch let error as SupabaseError where Self.isMissingFunction(error) {
            return nil
        }
    }

    func createSquad(name: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["squad_name": name])
        let data = try await rpc("create_squad", body: body)
        return try decoder.decode(String.self, from: data)
    }

    func joinSquad(code: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["invite_code": code])
        _ = try await rpc("join_squad", body: body)
    }

    func leaveSquad() async throws {
        _ = try await rpc("leave_squad", body: Data("{}".utf8))
    }

    private static let profileSelect = "id,username,invite_code,buddy_id,current_streak_days,streak_days,last_checkin_at"

    private struct ProfileRow: Decodable {
        let id: UUID
        let username: String?
        let inviteCode: String?
        let streakDays: Int?
        let currentStreakDays: Int?
        let lastCheckinAt: Date?
        let buddyId: UUID?

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case inviteCode
            case streakDays
            case currentStreakDays
            case lastCheckinAt
            case buddyId
        }

        var asUser: UserProfile {
            let name = username?.trimmingCharacters(in: .whitespacesAndNewlines)
            return UserProfile(
                id: id,
                username: (name?.isEmpty == false ? name! : "Воин"),
                inviteCode: inviteCode ?? "",
                streakDays: currentStreakDays ?? streakDays ?? 0,
                lastCheckinAt: lastCheckinAt,
                buddyId: buddyId,
                squadId: nil
            )
        }
    }

    private func ensureInviteCodeDirect() async throws -> UserProfile {
        guard let userId = currentUserId() else { throw BuddyError.unauthorized }
        var profile = try await loadOwnProfile()
        if profile == nil {
            let body = try JSONSerialization.data(withJSONObject: ["id": userId.uuidString])
            _ = try await rest(path: "profiles", method: "POST", body: body)
            profile = try await loadOwnProfile()
        }
        guard let profile else {
            throw SupabaseError.server("Профиль не создан. Открой приложение ещё раз при наличии сети.")
        }
        guard !Self.isShareable(profile.inviteCode) else { return profile }
        return try await saveInviteCode(for: userId)
    }

    private func saveInviteCode(for userId: UUID) async throws -> UserProfile {
        var lastError: Error = SupabaseError.server("Не удалось сохранить код приглашения")
        for _ in 0..<5 {
            let code = PartnerCode.generate()
            let body = try JSONSerialization.data(withJSONObject: ["invite_code": code])
            do {
                let updated = try await restData(path: "profiles?id=eq.\(userId.uuidString)", method: "PATCH", body: body)
                let raw = String(data: updated, encoding: .utf8) ?? ""
                supabaseLog("invite patch \(raw)")
                if let saved = try? decoder.decode([ProfileRow].self, from: updated).first?.asUser,
                   Self.isShareable(saved.inviteCode) {
                    return saved
                }
                if let saved = try await loadOwnProfile(), Self.isShareable(saved.inviteCode) {
                    return saved
                }
                lastError = SupabaseError.server("Не удалось сохранить код приглашения")
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func loadOwnProfile() async throws -> UserProfile? {
        guard let userId = currentUserId() else { throw BuddyError.unauthorized }
        return try await profileRows("profiles?id=eq.\(userId.uuidString)&select=\(Self.profileSelect)&limit=1").first?.asUser
    }

    private func loadProfile(id: UUID) async throws -> UserProfile? {
        try await profileRows("profiles?id=eq.\(id.uuidString)&select=\(Self.profileSelect)&limit=1").first?.asUser
    }

    private func profileRows(_ path: String) async throws -> [ProfileRow] {
        let data = try await restData(path: path, method: "GET", body: nil)
        return try decoder.decode([ProfileRow].self, from: data)
    }

    private static func isMissingFunction(_ error: SupabaseError) -> Bool {
        guard case .server(let message) = error else { return false }
        let lower = message.lowercased()
        return lower.contains("could not find the function") || lower.contains("pgrst202")
    }

    private static func isShareable(_ code: String) -> Bool {
        PartnerCode.isComplete(code) && code != "000000" && code != "ABCDEF"
    }

    private static func isNull(_ data: Data) -> Bool {
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text == nil || text == "null" || text?.isEmpty == true
    }

    private func rpc(_ name: String, body: Data) async throws -> Data {
        try await ensureSession()
        return try await restData(path: "rpc/\(name)", method: "POST", body: body)
    }

    func pullProfile() async throws -> RemoteProfile {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        let data = try await restData(
            path: "profiles?id=eq.\(userId.uuidString)&select=current_streak_days,best_streak_days,streak_start_date,last_relapse_at,last_streak_freeze_date",
            method: "GET",
            body: nil
        )
        let rows = try decoder.decode([RemoteProfile].self, from: data)
        return rows.first ?? RemoteProfile(currentStreakDays: 0, bestStreakDays: 0, streakStartDate: nil, lastRelapseAt: nil, lastStreakFreezeDate: nil)
    }

    func pushTotalXP(_ xp: Int) async {
        guard let userId = currentUserId() else { return }
        try? await ensureSession()
        guard let body = try? JSONSerialization.data(withJSONObject: ["total_xp": xp]) else { return }
        _ = try? await rest(path: "profiles?id=eq.\(userId.uuidString)", method: "PATCH", body: body)
    }

    func pushProfile(streakDays: Int, bestStreak: Int, streakStart: Date?, lastRelapse: Date?, lastFreeze: Date? = nil) async throws {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        var payload: [String: Any] = [
            "current_streak_days": streakDays,
            "best_streak_days": bestStreak,
            "streak_days": streakDays,
            "best_streak": bestStreak,
            "updated_at": Self.iso.string(from: Date())
        ]
        payload["streak_start_date"] = streakStart.map { Self.iso.string(from: $0) } ?? NSNull()
        payload["last_relapse_at"] = lastRelapse.map { Self.iso.string(from: $0) } ?? NSNull()
        payload["last_streak_freeze_date"] = lastFreeze.map { Self.iso.string(from: $0) } ?? NSNull()
        let body = try JSONSerialization.data(withJSONObject: payload)
        supabaseLog("profiles update streak_start_date=\(payload["streak_start_date"] ?? "null") last_relapse_at=\(payload["last_relapse_at"] ?? "null") best_streak_days=\(bestStreak) current_streak_days=\(streakDays)")
        let status = try await rest(path: "profiles?id=eq.\(userId.uuidString)", method: "PATCH", body: body)
        supabaseLog("profiles response status=\(status)")
    }

    func insertRelapse(at date: Date, reason: String?, notes: String?) async throws {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        var payload: [String: Any] = [
            "user_id": userId.uuidString,
            "relapsed_at": Self.iso.string(from: date)
        ]
        if let reason, !reason.isEmpty { payload["trigger_reason"] = reason }
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await rest(path: "relapses", method: "POST", body: body)
    }

    func insertJournal(mood: Int?, urge: Int?, prompt: String?, note: String) async throws {
        guard let userId = currentUserId() else { throw SupabaseError.notSignedIn }
        var payload: [String: Any] = [
            "user_id": userId.uuidString,
            "reflection_note": note
        ]
        if let mood { payload["mood_score"] = mood }
        if let urge { payload["urge_score"] = urge }
        if let prompt, !prompt.isEmpty { payload["prompt_text"] = prompt }
        let body = try JSONSerialization.data(withJSONObject: payload)
        supabaseLog("journal_entries payload mood=\(mood.map(String.init) ?? "null") urge=\(urge.map(String.init) ?? "null") notes=\(note)")
        let status = try await rest(path: "journal_entries", method: "POST", body: body)
        supabaseLog("journal_entries response status=\(status)")
    }

    func fetchJournal() async throws -> [RemoteJournalRow] {
        guard currentUserId() != nil else { throw SupabaseError.notSignedIn }
        let data = try await restData(
            path: "journal_entries?select=id,mood_score,urge_score,prompt_text,reflection_note,created_at&order=created_at.desc",
            method: "GET",
            body: nil
        )
        return try decoder.decode([RemoteJournalRow].self, from: data)
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func fetchArticles() async throws -> [KnowledgeArticle] {
        let data = try await restData(
            path: "knowledge_articles?select=id,tab_type,title,description,content,order_index&order=order_index.asc",
            method: "GET",
            body: nil
        )
        return try decoder.decode([KnowledgeArticle].self, from: data)
    }

    private func refresh() async throws {
        guard let refreshToken = sessionBox.session?.refreshToken else {
            try await signInAnonymously()
            return
        }
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        let data = try await auth(path: "token?grant_type=refresh_token", method: "POST", body: body, authorized: false)
        sessionBox.session = try decodeSession(data)
    }

    private func auth(path: String, method: String, body: Data?, authorized: Bool) async throws -> Data {
        guard let url = Self.endpoint("auth/v1/\(path)") else { throw SupabaseError.notConfigured }
        return try await send(url: url, method: method, body: body, authorized: authorized).data
    }

    /// Возвращает HTTP-статус, чтобы вызывающий код мог записать его в лог.
    private func rest(path: String, method: String, body: Data?) async throws -> Int {
        guard let url = Self.endpoint("rest/v1/\(path)") else { throw SupabaseError.notConfigured }
        return try await send(url: url, method: method, body: body, authorized: true).status
    }

    private func restData(path: String, method: String, body: Data?) async throws -> Data {
        guard let url = Self.endpoint("rest/v1/\(path)") else { throw SupabaseError.notConfigured }
        return try await send(url: url, method: method, body: body, authorized: true).data
    }

    private static func endpoint(_ path: String) -> URL? {
        guard SupabaseConfig.isConfigured else { return nil }
        let root = SupabaseConfig.url.hasSuffix("/") ? String(SupabaseConfig.url.dropLast()) : SupabaseConfig.url
        return URL(string: "\(root)/\(path)")
    }

    private func send(url: URL, method: String, body: Data?, authorized: Bool) async throws -> (data: Data, status: Int) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.httpBody = body
        request.assumesHTTP3Capable = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if authorized, let token = sessionBox.session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            supabaseLog("\(method) \(url.path) network error \(error.code.rawValue)")
            throw SupabaseError.offline
        } catch {
            supabaseLog("\(method) \(url.path) failed \(error.localizedDescription)")
            throw SupabaseError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.server("Пустой ответ сервера")
        }
        if http.statusCode >= 500 {
            supabaseLog("\(method) \(url.path) response status=\(http.statusCode)")
            throw SupabaseError.server("Попробуйте позже")
        }
        guard (200..<300).contains(http.statusCode) else {
            supabaseLog("\(method) \(url.path) response status=\(http.statusCode)")
            let message = String(data: data, encoding: .utf8) ?? "Ошибка \(http.statusCode)"
            throw SupabaseError.server(message)
        }
        return (data: data, status: http.statusCode)
    }

    private func decodeSession(_ data: Data) throws -> SupabaseSession {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let source = (json?["session"] as? [String: Any]) ?? json
        guard
            let access = source?["access_token"] as? String,
            let refresh = source?["refresh_token"] as? String,
            let user = source?["user"] as? [String: Any],
            let idRaw = user["id"] as? String,
            let userId = UUID(uuidString: idRaw)
        else {
            throw SupabaseError.server("Сервер не вернул сессию. Включите Anonymous Sign-Ins в Supabase.")
        }
        let expiresIn = (source?["expires_in"] as? Int) ?? 3600
        return SupabaseSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            userId: userId
        )
    }
}

private final class SessionBox {
    var session: SupabaseSession? {
        didSet { persist() }
    }

    init() {
        guard let data = KeychainStore.load() else { return }
        session = try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    private func persist() {
        guard let session else {
            KeychainStore.clear()
            return
        }
        if let data = try? JSONEncoder().encode(session) {
            KeychainStore.save(data)
        }
    }
}
