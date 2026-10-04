//
//  SupabasePartnerSync.swift
//  NoFap
//

import Foundation

@MainActor
final class SupabasePartnerSync: PartnerSyncing {
    private let client = SupabaseClient()

    func prepare() async throws -> String {
        try await client.ensureSession()
        guard let id = client.currentUserId() else { throw BuddyError.unauthorized }
        return id.uuidString
    }

    func publish(_ snapshot: OwnSnapshot) async throws {
        _ = snapshot
    }

    func createInvite() async throws -> PartnerInvite {
        let profile = try await client.ensureInviteCode()
        return PartnerInvite(code: profile.inviteCode, expiresAt: .distantFuture)
    }

    func cancelInvite() async throws {}

    func pollInviteAcceptance() async throws -> PartnerProfile? {
        try await fetchPartner()
    }

    func preview(code: String) async throws -> PartnerProfile {
        Self.profile(try await lookup(code))
    }

    func redeem(code: String) async throws -> PartnerProfile {
        let normalized = PartnerCode.normalize(code)
        _ = try await lookup(normalized)
        let paired = try await client.pairWithBuddy(code: normalized)
        return Self.profile(paired)
    }

    private func lookup(_ code: String) async throws -> UserProfile {
        let normalized = PartnerCode.normalize(code)
        guard PartnerCode.isComplete(normalized) else { throw BuddyError.invalidCodeLength }
        let found = try await client.lookupBuddy(code: normalized)
        guard let me = client.currentUserId() else { throw BuddyError.unauthorized }
        guard found.id != me else { throw BuddyError.cannotPairWithSelf }
        if found.buddyId != nil { throw BuddyError.buddyAlreadyPaired }
        return found
    }

    func fetchPartner() async throws -> PartnerProfile? {
        guard let buddy = try await client.fetchCurrentBuddy() else { return nil }
        return Self.profile(buddy)
    }

    func unpair() async throws {}

    func fetchMessages() async throws -> [PartnerMessage] {
        let rows = try await client.fetchMessages()
        let me = client.currentUserId()
        return rows.map {
            PartnerMessage(
                id: $0.id.uuidString,
                kind: .text,
                text: $0.text,
                isMine: $0.senderId == me,
                sentAt: $0.createdAt
            )
        }
    }

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage {
        guard let buddy = try await client.fetchCurrentBuddy() else { throw PartnerSyncError.partnerGone }
        try await client.sendBuddyMessage(to: buddy.id, text: text)
        return PartnerMessage.mine(text, kind: kind)
    }

    private static func profile(_ user: UserProfile) -> PartnerProfile {
        let day = user.lastCheckinAt.map { DayKey.string(from: $0) }
        return PartnerProfile(
            id: user.id.uuidString,
            nickname: user.username,
            currentStreak: user.streakDays,
            goalDays: 0,
            lastCheckInDay: day,
            updatedAt: user.lastCheckinAt ?? Date()
        )
    }
}
