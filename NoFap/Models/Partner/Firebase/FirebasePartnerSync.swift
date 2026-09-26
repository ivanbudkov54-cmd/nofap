//
//  FirebasePartnerSync.swift
//  NoFap
//
//  Напарник на Firestore. Данные на сервере:
//
//    profiles/{uid}              — прозвище, стрик, цель, день отметки,
//                                  partnerId (с кем в паре)
//    invites/{code}              — ownerId, acceptedBy, expiresAt
//    pairs/{uidA_uidB}/messages  — переписка; uid в имени отсортированы,
//                                  поэтому пара у обоих называется одинаково
//
//  Связь двусторонняя: каждый пишет partnerId только в свой профиль.
//  Присоединившийся отмечает себя в приглашении, а пригласивший, увидев
//  это, вписывает его к себе — чужой профиль правила менять не дают.
//
//  Кто что может — в firestore.rules в корне репозитория.
//

import Foundation

@MainActor
final class FirebasePartnerSync: PartnerSyncing {

    private let session = FirebaseSession()
    private lazy var db = Firestore(session: session)

    /// Код своего открытого приглашения. Локально: после перезапуска
    /// приложения нужно суметь его проверить или отозвать.
    private var inviteCode: String? {
        get { UserDefaults.standard.string(forKey: "firebase.inviteCode") }
        set { UserDefaults.standard.set(newValue, forKey: "firebase.inviteCode") }
    }

    /// Кэш на время жизни процесса — чат опрашивается каждые пару секунд,
    /// перечитывать ради него свой профиль незачем.
    private var knownPartnerID: String?

    /// Переписка копится здесь, а с сервера догружается только новое.
    private var messageCache: [PartnerMessage] = []
    private var messagesSince: Date?
    private var messagesPair: String?

    // MARK: - PartnerSyncing

    func prepare() async throws -> String {
        try await call { try await session.userID() }
    }

    func publish(_ snapshot: OwnSnapshot) async throws {
        try await call {
            let me = try await session.userID()
            try await db.set("profiles/\(me)", [
                "nickname": .string(snapshot.nickname),
                "currentStreak": .int(snapshot.currentStreak),
                "goalDays": .int(snapshot.goalDays),
                "lastCheckInDay": snapshot.lastCheckInDay.map(FirestoreValue.string) ?? .null,
                "updatedAt": .time(Date())
            ], mask: ["nickname", "currentStreak", "goalDays", "lastCheckInDay", "updatedAt"])
        }
    }

    func createInvite() async throws -> PartnerInvite {
        try await call {
            let me = try await session.userID()
            guard try await partnerID() == nil else { throw PartnerSyncError.alreadyPaired }
            try await removeOwnInvite()

            // Заводим профиль заранее: присоединившийся сразу читает его,
            // и пустота на его месте выглядела бы как разорванная связь.
            try await setPartnerID(nil)

            // Совпадение с чужим кодом почти невероятно, но не исключено.
            for _ in 0..<3 {
                let invite = PartnerInvite(code: PartnerCode.generate(),
                                           expiresAt: Date().addingTimeInterval(15 * 60))
                do {
                    try await db.set("invites/\(invite.code)", [
                        "ownerId": .string(me),
                        "acceptedBy": .null,
                        "expiresAt": .time(invite.expiresAt)
                    ], mustNotExist: true)
                    inviteCode = invite.code
                    return invite
                } catch FirestoreError.conflict {
                    continue
                }
            }
            throw PartnerSyncError.network
        }
    }

    func cancelInvite() async throws {
        try await call { try await removeOwnInvite() }
    }

    func pollInviteAcceptance() async throws -> PartnerProfile? {
        try await call { try await acceptIfTaken() }
    }

    func redeem(code: String) async throws -> PartnerProfile {
        try await call {
            let me = try await session.userID()
            guard try await partnerID() == nil else { throw PartnerSyncError.alreadyPaired }

            guard let invite = try await db.get("invites/\(code)"),
                  let owner = invite.string("ownerId") else { throw PartnerSyncError.codeNotFound }
            guard owner != me else { throw PartnerSyncError.codeIsMine }
            guard invite.string("acceptedBy") == nil else { throw PartnerSyncError.codeAlreadyUsed }
            guard (invite.date("expiresAt") ?? .distantPast) > Date() else { throw PartnerSyncError.codeExpired }

            // updateTime как условие: если кто-то успел принять код между
            // чтением и записью, сервер откажет, а не перезапишет.
            do {
                try await db.set("invites/\(code)", ["acceptedBy": .string(me)],
                                 mask: ["acceptedBy"], unchangedSince: invite.updateTime)
            } catch FirestoreError.conflict, FirestoreError.denied {
                throw PartnerSyncError.codeAlreadyUsed
            }

            try await setPartnerID(owner)
            try await removeOwnInvite()
            return try await profile(of: owner) ?? placeholder(owner)
        }
    }

    func fetchPartner() async throws -> PartnerProfile? {
        try await call {
            let me = try await session.userID()
            guard let partner = try await partnerID(refresh: true) else {
                // Код могли принять, пока приложение было закрыто.
                return try await acceptIfTaken()
            }

            guard let doc = try await db.get("profiles/\(partner)") else {
                try await setPartnerID(nil)
                throw PartnerSyncError.partnerGone
            }
            // Пустой partnerId у напарника — он ещё не увидел, что код
            // приняли. Разрыв — только если там чужой идентификатор.
            if let theirs = doc.string("partnerId"), theirs != me {
                try await setPartnerID(nil)
                throw PartnerSyncError.partnerGone
            }
            return profile(from: doc)
        }
    }

    func unpair() async throws {
        try await call {
            let me = try await session.userID()
            if let partner = try await partnerID() {
                let pair = pairID(me, partner)
                let all = (try? await db.documents(in: "pairs/\(pair)", collection: "messages",
                                                   orderedBy: "sentAt", since: nil)) ?? []
                for message in all {
                    try? await db.delete("pairs/\(pair)/messages/\(message.id)")
                }
            }
            try? await removeOwnInvite()
            try? await db.delete("profiles/\(me)")

            // Новый идентификатор — бывший напарник знает только старый.
            await session.deleteAccount()
            knownPartnerID = nil
            resetMessages()
        }
    }

    // MARK: - Переписка

    func fetchMessages() async throws -> [PartnerMessage] {
        try await call {
            let me = try await session.userID()
            guard let partner = try await partnerID() else { return [] }
            let pair = pairID(me, partner)
            if pair != messagesPair { resetMessages(); messagesPair = pair }

            let fresh = try await db.documents(in: "pairs/\(pair)", collection: "messages",
                                               orderedBy: "sentAt", since: messagesSince)
            let known = Set(messageCache.map(\.id))
            for doc in fresh where !known.contains(doc.id) {
                if let message = message(from: doc, me: me) { messageCache.append(message) }
            }
            messageCache.sort { $0.sentAt < $1.sentAt }
            messagesSince = messageCache.last?.sentAt
            return messageCache
        }
    }

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage {
        try await call {
            let me = try await session.userID()
            guard let partner = try await partnerID() else { throw PartnerSyncError.partnerGone }

            let id = UUID().uuidString
            let sentAt = try await db.create("pairs/\(pairID(me, partner))/messages/\(id)", [
                "senderId": .string(me),
                "kind": .string(kind.rawValue),
                "text": .string(text)
            ], serverTimeField: "sentAt")

            let message = PartnerMessage(id: id, kind: kind, text: text, isMine: true, sentAt: sentAt)
            messageCache.append(message)
            return message
        }
    }

    // MARK: - Внутреннее

    /// Все ошибки наружу — только в словаре PartnerSyncError: интерфейс
    /// не должен знать ни про HTTP, ни про Firestore.
    private func call<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as PartnerSyncError {
            throw error
        } catch FirebaseAuthError.notConfigured {
            throw PartnerSyncError.other(String(localized: "Сервер напарника не настроен."))
        } catch FirestoreError.denied {
            throw PartnerSyncError.other(String(localized: "Сервер отклонил запрос. Попробуй позже."))
        } catch {
            throw PartnerSyncError.network
        }
    }

    private func partnerID(refresh: Bool = false) async throws -> String? {
        if !refresh, let knownPartnerID { return knownPartnerID }
        let me = try await session.userID()
        knownPartnerID = try await db.get("profiles/\(me)")?.string("partnerId")
        return knownPartnerID
    }

    private func setPartnerID(_ partner: String?) async throws {
        let me = try await session.userID()
        try await db.set("profiles/\(me)", [
            "partnerId": partner.map(FirestoreValue.string) ?? .null,
            "updatedAt": .time(Date())
        ], mask: ["partnerId", "updatedAt"])
        knownPartnerID = partner
        if partner == nil { resetMessages() }
    }

    /// Проверить своё приглашение: если его приняли — закрепить связь.
    private func acceptIfTaken() async throws -> PartnerProfile? {
        guard let code = inviteCode else { return nil }
        guard let invite = try await db.get("invites/\(code)") else {
            inviteCode = nil
            return nil
        }
        guard let joiner = invite.string("acceptedBy") else { return nil }

        try await setPartnerID(joiner)
        try await removeOwnInvite()
        return try await profile(of: joiner) ?? placeholder(joiner)
    }

    private func removeOwnInvite() async throws {
        guard let code = inviteCode else { return }
        try await db.delete("invites/\(code)")
        inviteCode = nil
    }

    private func profile(of uid: String) async throws -> PartnerProfile? {
        try await db.get("profiles/\(uid)").map(profile(from:))
    }

    private func profile(from doc: FirestoreDocument) -> PartnerProfile {
        PartnerProfile(id: doc.id,
                       nickname: doc.string("nickname") ?? String(localized: "Напарник"),
                       currentStreak: doc.int("currentStreak") ?? 0,
                       goalDays: doc.int("goalDays") ?? 0,
                       lastCheckInDay: doc.string("lastCheckInDay"),
                       updatedAt: doc.date("updatedAt") ?? Date())
    }

    /// Напарник ещё не успел опубликовать себя — покажем имя-заглушку,
    /// настоящие данные подтянутся при следующем обновлении.
    private func placeholder(_ uid: String) -> PartnerProfile {
        PartnerProfile(id: uid, nickname: String(localized: "Напарник"),
                       currentStreak: 0, goalDays: 0, lastCheckInDay: nil, updatedAt: Date())
    }

    private func message(from doc: FirestoreDocument, me: String) -> PartnerMessage? {
        guard let text = doc.string("text"),
              let kind = doc.string("kind").flatMap(PartnerMessage.Kind.init(rawValue:)),
              let sentAt = doc.date("sentAt") else { return nil }
        return PartnerMessage(id: doc.id, kind: kind, text: text,
                              isMine: doc.string("senderId") == me, sentAt: sentAt)
    }

    private func pairID(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }

    private func resetMessages() {
        messageCache = []
        messagesSince = nil
        messagesPair = nil
    }
}
