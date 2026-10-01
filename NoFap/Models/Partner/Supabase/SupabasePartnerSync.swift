//
//  SupabasePartnerSync.swift
//  NoFap
//
//  Напарник на Supabase. Всё, что меняет данные, — функции из
//  supabase/schema.sql; приложение только читает таблицы, и только то,
//  что разрешают политики: свой профиль, профиль взаимного напарника,
//  свои приглашения и свою переписку.
//
//  Связывание атомарное: redeem_invite ставит partner_id обоим сразу, так
//  что пригласившему не нужно ничего подтверждать — он просто увидит пару
//  при следующем опросе.
//

import Foundation

@MainActor
final class SupabasePartnerSync: PartnerSyncing {

    private let session = SupabaseSession.shared
    private lazy var db = SupabaseClient(session: session)

    /// Кэш на время жизни процесса — чат опрашивается каждые пару секунд,
    /// перечитывать ради него свой профиль незачем.
    private var knownPartnerID: String?

    /// Переписка копится здесь, а с сервера догружается только новое.
    private var messageCache: [PartnerMessage] = []
    private var messagesSince: Date?
    private var messagesPartner: String?

    // MARK: - PartnerSyncing

    func prepare() async throws -> String {
        try await call {
            let me = try await session.userID()
            try await db.call("ensure_profile")
            return me
        }
    }

    func publish(_ snapshot: OwnSnapshot) async throws {
        try await call {
            try await db.call("publish_profile", [
                "p_nickname": snapshot.nickname,
                "p_current_streak": snapshot.currentStreak,
                "p_goal_days": snapshot.goalDays,
                "p_last_check_in_day": snapshot.lastCheckInDay
            ])
        }
    }

    func createInvite() async throws -> PartnerInvite {
        try await call {
            let row: InviteRow = try await db.call("create_invite")
            return PartnerInvite(code: row.code, expiresAt: row.expiresAt)
        }
    }

    func cancelInvite() async throws {
        try await call { try await db.call("cancel_invite") }
    }

    func pollInviteAcceptance() async throws -> PartnerProfile? {
        try await call { try await currentPartner() }
    }

    func redeem(code: String) async throws -> PartnerProfile {
        try await call {
            let row: SupabaseProfileRow = try await db.call("redeem_invite", ["p_code": code])
            knownPartnerID = row.id
            return row.profile
        }
    }

    func fetchPartner() async throws -> PartnerProfile? {
        try await call { try await currentPartner() }
    }

    func unpair() async throws {
        try await call {
            try await db.call("unpair")
            knownPartnerID = nil
            resetMessages()
        }
    }

    // MARK: - Переписка

    func fetchMessages() async throws -> [PartnerMessage] {
        try await call {
            let me = try await session.userID()
            guard let partner = try await partnerID() else { return [] }
            if partner != messagesPartner {
                resetMessages()
                messagesPartner = partner
            }

            var filters = [
                ("or", "(and(sender_id.eq.\(me),recipient_id.eq.\(partner)),and(sender_id.eq.\(partner),recipient_id.eq.\(me)))"),
                ("order", "sent_at.asc")
            ]
            if let messagesSince {
                filters.append(("sent_at", "gte.\(PostgresTime.string(from: messagesSince))"))
            }

            let rows: [MessageRow] = try await db.select("messages", filters)
            let known = Set(messageCache.map(\.id))
            for row in rows where !known.contains(row.id) {
                if let message = row.message(me: me) { messageCache.append(message) }
            }
            messageCache.sort { $0.sentAt < $1.sentAt }
            messagesSince = messageCache.last?.sentAt
            return messageCache
        }
    }

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage {
        try await call {
            let me = try await session.userID()
            let row: MessageRow = try await db.call("send_message", ["p_kind": kind.rawValue, "p_body": text])
            guard let message = row.message(me: me) else { throw PartnerSyncError.network }
            messageCache.append(message)
            return message
        }
    }

    // MARK: - Внутреннее

    private func call<T>(_ body: () async throws -> T) async throws -> T {
        try await supabaseCall(body)
    }

    /// Напарник, если связь взаимная. Если моя сторона на кого-то указывает,
    /// а его профиль не читается (удалён или связь снята с той стороны), —
    /// подчищаю свою сторону и сообщаю о разрыве.
    private func currentPartner() async throws -> PartnerProfile? {
        guard let partner = try await partnerID(refresh: true) else { return nil }
        let rows: [SupabaseProfileRow] = try await db.select("profiles", [("id", "eq.\(partner)")])
        guard let row = rows.first else {
            try await db.call("unpair")
            knownPartnerID = nil
            resetMessages()
            throw PartnerSyncError.partnerGone
        }
        return row.profile
    }

    private func partnerID(refresh: Bool = false) async throws -> String? {
        if !refresh, let knownPartnerID { return knownPartnerID }
        let me = try await session.userID()
        let rows: [SupabaseProfileRow] = try await db.select("profiles", [("id", "eq.\(me)")])
        knownPartnerID = rows.first?.partnerId
        return knownPartnerID
    }

    private func resetMessages() {
        messageCache = []
        messagesSince = nil
        messagesPartner = nil
    }
}

// MARK: - Строки таблиц

struct SupabaseProfileRow: Decodable {
    let id: String
    let nickname: String
    let currentStreak: Int
    let goalDays: Int
    let lastCheckInDay: String?
    let partnerId: String?
    let updatedAt: Date

    var profile: PartnerProfile {
        PartnerProfile(id: id, nickname: nickname, currentStreak: currentStreak,
                       goalDays: goalDays, lastCheckInDay: lastCheckInDay, updatedAt: updatedAt)
    }
}

private struct InviteRow: Decodable {
    let code: String
    let expiresAt: Date
}

private struct MessageRow: Decodable {
    let id: String
    let senderId: String
    let kind: String
    let body: String
    let sentAt: Date

    func message(me: String) -> PartnerMessage? {
        guard let kind = PartnerMessage.Kind(rawValue: kind) else { return nil }
        return PartnerMessage(id: id, kind: kind, text: body, isMine: senderId == me, sentAt: sentAt)
    }
}
