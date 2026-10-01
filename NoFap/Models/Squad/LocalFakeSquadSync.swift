//
//  LocalFakeSquadSync.swift
//  NoFap
//
//  Поддельный сквад для одного симулятора: после создания приглашения
//  участники «вступают» сами, а в чате кто-то из них отвечает. Так весь
//  сценарий видно без сервера и без второго телефона.
//

import Foundation

@MainActor
final class LocalFakeSquadSync: SquadSyncing {

    /// Когда после создания приглашения вступает каждый выдуманный участник.
    /// Третье место намеренно остаётся пустым — его тоже нужно видеть.
    private static let joinDelays: [TimeInterval] = [10, 25]

    private static let sampleMembers: [(name: String, streak: Int, goal: Int, holding: Bool)] = [
        (String(localized: "Тимур"), 23, 30, true),
        (String(localized: "Лёва"), 6, 21, false)
    ]

    private let latency: Duration = .milliseconds(500)
    private let defaults: UserDefaults

    private enum Key {
        static let inSquad = "fake.inSquad"
        static let invite = "fake.invite"
        static let inviteCreated = "fake.inviteCreated"
        static let joined = "fake.joinedCount"
        static let messages = "fake.messages"
    }

    /// Отдельный suite, как у заглушки напарника: выдуманные данные не
    /// смешиваются с настоящими.
    init(defaults: UserDefaults = UserDefaults(suiteName: "squad.fake")!) {
        self.defaults = defaults
    }

    // MARK: - SquadSyncing

    func fetchSquad() async throws -> SquadSnapshot? {
        try await simulateCall()
        guard defaults.bool(forKey: Key.inSquad) else { return nil }

        if let created = defaults.object(forKey: Key.inviteCreated) as? Date {
            let due = Self.joinDelays.filter { Date().timeIntervalSince(created) >= $0 }.count
            if due > joinedCount { defaults.set(due, forKey: Key.joined) }
        }
        return snapshot
    }

    func createInvite() async throws -> PartnerInvite {
        try await simulateCall()
        guard joinedCount < SquadLimits.maxMembers - 1 else { throw PartnerSyncError.squadFull }

        defaults.set(true, forKey: Key.inSquad)
        let invite = PartnerInvite(code: PartnerCode.generate(),
                                   expiresAt: Date().addingTimeInterval(SquadLimits.inviteLifetime))
        defaults.set(invite.code, forKey: Key.invite)
        defaults.set(invite.expiresAt, forKey: "\(Key.invite).expires")
        if defaults.object(forKey: Key.inviteCreated) == nil {
            defaults.set(Date(), forKey: Key.inviteCreated)
        }
        return invite
    }

    func cancelInvite() async throws {
        try await simulateCall()
        defaults.removeObject(forKey: Key.invite)
        defaults.removeObject(forKey: "\(Key.invite).expires")
    }

    func join(code: String) async throws -> SquadSnapshot {
        try await simulateCall()
        guard !defaults.bool(forKey: Key.inSquad) else { throw PartnerSyncError.alreadyInSquad }
        guard PartnerCode.isComplete(code) else { throw PartnerSyncError.codeNotFound }

        defaults.set(true, forKey: Key.inSquad)
        defaults.set(Self.sampleMembers.count, forKey: Key.joined)
        return snapshot
    }

    func leave() async throws {
        try await simulateCall()
        [Key.inSquad, Key.invite, "\(Key.invite).expires", Key.inviteCreated, Key.joined, Key.messages]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    func publish(_ snapshot: OwnSnapshot) async throws {}

    // MARK: - Переписка

    func fetchMessages() async throws -> [PartnerMessage] {
        try await simulateCall()
        return storedMessages
    }

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage {
        try await simulateCall()
        guard defaults.bool(forKey: Key.inSquad) else { throw PartnerSyncError.partnerGone }

        let message = PartnerMessage.mine(text, kind: kind)
        store(messages: storedMessages + [message])
        scheduleReply(to: kind)
        return message
    }

    // MARK: - Внутреннее

    private var joinedCount: Int { defaults.integer(forKey: Key.joined) }

    private var snapshot: SquadSnapshot {
        let members = Self.sampleMembers.prefix(joinedCount).enumerated().map { index, sample in
            PartnerProfile(id: "fake-squad-\(index)",
                           nickname: sample.name,
                           currentStreak: sample.streak,
                           goalDays: sample.goal,
                           lastCheckInDay: sample.holding ? DayKey.today() : nil,
                           updatedAt: Date())
        }
        var invite: PartnerInvite?
        if let code = defaults.string(forKey: Key.invite),
           let expires = defaults.object(forKey: "\(Key.invite).expires") as? Date, expires > Date() {
            invite = PartnerInvite(code: code, expiresAt: expires)
        }
        return SquadSnapshot(members: Array(members), invite: invite)
    }

    private func scheduleReply(to kind: PartnerMessage.Kind) {
        let members = snapshot.members
        guard let author = members.randomElement() else { return }
        let text = kind == .sos
            ? ChatPresets.support.randomElement() ?? String(localized: "Я рядом")
            : [String(localized: "Держимся вместе"), String(localized: "Сегодня тоже отметился"),
               String(localized: "Как ты?")].randomElement()!

        Task { [weak self] in
            try? await Task.sleep(for: kind == .sos ? .seconds(3) : .seconds(6))
            guard let self else { return }
            let reply = PartnerMessage(id: UUID().uuidString,
                                       kind: kind == .sos ? .support : .text,
                                       text: text,
                                       isMine: false,
                                       sentAt: Date(),
                                       senderName: author.nickname)
            self.store(messages: self.storedMessages + [reply])
        }
    }

    private var storedMessages: [PartnerMessage] {
        guard let data = defaults.data(forKey: Key.messages) else { return [] }
        return (try? JSONDecoder().decode([PartnerMessage].self, from: data)) ?? []
    }

    private func store(messages: [PartnerMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: Key.messages)
        }
    }

    private func simulateCall() async throws {
        try? await Task.sleep(for: latency)
    }
}
