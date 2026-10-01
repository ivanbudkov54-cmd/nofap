//
//  SupabaseSquadSync.swift
//  NoFap
//
//  Сквад на Supabase. Как и у напарника: всё, что меняет данные, — функции
//  из supabase/schema.sql, а таблицы приложение только читает, и политики
//  отдают лишь свой сквад.
//

import Foundation

@MainActor
final class SupabaseSquadSync: SquadSyncing {

    private let session = SupabaseSession.shared
    private lazy var db = SupabaseClient(session: session)

    /// Имена участников для подписей в чате — обновляются при каждом
    /// чтении состава.
    private var names: [String: String] = [:]
    private var squadID: String?

    private var messageCache: [PartnerMessage] = []
    private var messagesSince: Date?
    private var messagesSquad: String?

    // MARK: - SquadSyncing

    func fetchSquad() async throws -> SquadSnapshot? {
        try await supabaseCall { () -> SquadSnapshot? in
            let me = try await session.userID()
            let memberRows: [MemberRow] = try await db.select("squad_members", [("order", "joined_at.asc")])
            guard let squad = memberRows.first?.squadId else {
                squadID = nil
                return nil
            }
            squadID = squad

            let others = memberRows.map(\.userId).filter { $0 != me }
            var profiles: [PartnerProfile] = []
            if !others.isEmpty {
                let rows: [SupabaseProfileRow] = try await db.select(
                    "profiles", [("id", "in.(\(others.joined(separator: ",")))")])
                // Порядок — по времени вступления, а не как отдала база.
                profiles = others.compactMap { id in rows.first { $0.id == id }?.profile }
            }
            names = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.nickname) })

            let invites: [InviteRow] = try await db.select(
                "squad_invites", [("order", "created_at.desc"), ("limit", "1")])
            let invite = invites
                .first { $0.expiresAt > Date() }
                .map { PartnerInvite(code: $0.code, expiresAt: $0.expiresAt) }

            return SquadSnapshot(members: profiles, invite: invite)
        }
    }

    func createInvite() async throws -> PartnerInvite {
        try await supabaseCall {
            let row: InviteRow = try await db.call("create_squad_invite")
            return PartnerInvite(code: row.code, expiresAt: row.expiresAt)
        }
    }

    func cancelInvite() async throws {
        try await supabaseCall { try await db.call("cancel_squad_invite") }
    }

    func join(code: String) async throws -> SquadSnapshot {
        try await supabaseCall { try await db.call("join_squad", ["p_code": code]) }
        guard let snapshot = try await fetchSquad() else { throw PartnerSyncError.network }
        return snapshot
    }

    func leave() async throws {
        try await supabaseCall {
            try await db.call("leave_squad")
            squadID = nil
            names = [:]
            resetMessages()
        }
    }

    func publish(_ snapshot: OwnSnapshot) async throws {
        try await supabaseCall {
            try await db.call("publish_profile", [
                "p_nickname": snapshot.nickname,
                "p_current_streak": snapshot.currentStreak,
                "p_goal_days": snapshot.goalDays,
                "p_last_check_in_day": snapshot.lastCheckInDay
            ])
        }
    }

    // MARK: - Переписка

    func fetchMessages() async throws -> [PartnerMessage] {
        if squadID == nil { _ = try await fetchSquad() }
        return try await supabaseCall {
            let me = try await session.userID()
            guard let squad = squadID else { return [] }
            if squad != messagesSquad {
                resetMessages()
                messagesSquad = squad
            }

            var filters = [("squad_id", "eq.\(squad)"), ("order", "sent_at.asc")]
            if let messagesSince {
                filters.append(("sent_at", "gte.\(PostgresTime.string(from: messagesSince))"))
            }

            let rows: [SquadMessageRow] = try await db.select("squad_messages", filters)
            let known = Set(messageCache.map(\.id))
            for row in rows where !known.contains(row.id) {
                if let message = message(from: row, me: me) { messageCache.append(message) }
            }
            messageCache.sort { $0.sentAt < $1.sentAt }
            messagesSince = messageCache.last?.sentAt
            return messageCache
        }
    }

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage {
        try await supabaseCall {
            let me = try await session.userID()
            let row: SquadMessageRow = try await db.call("send_squad_message",
                                                         ["p_kind": kind.rawValue, "p_body": text])
            guard let sent = message(from: row, me: me) else { throw PartnerSyncError.network }
            messageCache.append(sent)
            return sent
        }
    }

    // MARK: - Внутреннее

    private func message(from row: SquadMessageRow, me: String) -> PartnerMessage? {
        guard let kind = PartnerMessage.Kind(rawValue: row.kind) else { return nil }
        let isMine = row.senderId == me
        return PartnerMessage(
            id: row.id, kind: kind, text: row.body, isMine: isMine, sentAt: row.sentAt,
            // Вышедший из сквада участник: имя уже не прочитать, а сообщение
            // остаётся в истории.
            senderName: isMine ? nil : row.senderId.flatMap { names[$0] } ?? String(localized: "Бывший участник")
        )
    }

    private func resetMessages() {
        messageCache = []
        messagesSince = nil
        messagesSquad = nil
    }
}

// MARK: - Строки таблиц

private struct MemberRow: Decodable {
    let squadId: String
    let userId: String
}

private struct InviteRow: Decodable {
    let code: String
    let expiresAt: Date
}

private struct SquadMessageRow: Decodable {
    let id: String
    let senderId: String?
    let kind: String
    let body: String
    let sentAt: Date
}
