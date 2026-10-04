//
//  BuddySquadModels.swift
//  NoFap
//

import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let inviteCode: String
    let streakDays: Int
    let lastCheckinAt: Date?
    let buddyId: UUID?
    let squadId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case inviteCode = "invite_code"
        case streakDays = "streak_days"
        case lastCheckinAt = "last_checkin_at"
        case buddyId = "buddy_id"
        case squadId = "squad_id"
    }

    var checkinNote: String {
        guard let lastCheckinAt else { return "Чекина ещё не было" }
        let hours = max(0, Int(Date().timeIntervalSince(lastCheckinAt) / 3600))
        if hours < 1 { return "Чекин только что" }
        return "Последний чекин \(hours) ч. назад"
    }
}

struct BuddyPair: Codable, Identifiable, Equatable {
    let id: UUID
    let user1Id: UUID
    let user2Id: UUID
    let createdAt: Date
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
        case status
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let receiverId: UUID
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case text
        case createdAt = "created_at"
    }
}

struct BuddyModel: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let buddyId: UUID?
    let status: String
    let inviteCode: String
    let streakDays: Int
    let lastCheckin: Date?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case buddyId = "buddy_id"
        case status
        case inviteCode = "invite_code"
        case streakDays = "streak_days"
        case lastCheckin = "last_checkin"
        case name
    }

    var isAccepted: Bool { status == "accepted" && buddyId != nil }

    var checkinNote: String {
        guard let lastCheckin else { return "Чекина ещё не было" }
        let hours = max(0, Int(Date().timeIntervalSince(lastCheckin) / 3600))
        return "Чекин сделан \(hours) ч. назад"
    }
}

struct SquadMember: Codable, Identifiable, Equatable {
    let userId: UUID
    let name: String
    let streakDays: Int
    let lastCheckin: Date?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case streakDays = "streak_days"
        case lastCheckin = "last_checkin"
    }
}

struct SquadModel: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let inviteCode: String
    let memberCount: Int
    let totalStreakDays: Int
    var members: [SquadMember]

    var squadCode: String { inviteCode }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case memberCount = "member_count"
        case totalStreakDays = "total_streak_days"
        case members
    }
}

struct SquadRosterRow: Decodable {
    let id: UUID
    let name: String
    let inviteCode: String
    let userId: UUID
    let memberName: String
    let streakDays: Int
    let lastCheckin: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case userId = "user_id"
        case memberName = "member_name"
        case streakDays = "streak_days"
        case lastCheckin = "last_checkin"
    }
}
