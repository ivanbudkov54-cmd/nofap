//
//  LocalFakePartnerSync.swift
//  NoFap
//
//  Поддельная синхронизация: позволяет собрать и проверить весь экран
//  напарника в одном симуляторе, без сети и без платного аккаунта
//  разработчика. Остаётся в проекте навсегда — на ней удобно снимать
//  скриншоты для App Store и показывать фичу без второго телефона.
//

import Foundation

@MainActor
final class LocalFakePartnerSync: PartnerSyncing {

    /// Сценарий, который проигрывает заглушка. Нужен, чтобы посмотреть
    /// глазами те состояния, которые иначе увидишь только в проде.
    enum Scenario: String, CaseIterable {
        case happy          = "Всё работает"
        case noAccount      = "Нет входа в iCloud"
        case flaky          = "Связь рвётся"
        case codeNotFound   = "Код не найден"
        case partnerLeft    = "Напарник ушёл"
    }

    var scenario: Scenario = .happy

    /// Через сколько секунд после создания кода «напарник» его примет.
    /// Именно поэтому состояние ожидания реально видно в одном симуляторе.
    var acceptanceDelay: TimeInterval = 20

    private let latency: Duration = .milliseconds(600)

    /// Отдельный suite: поддельные данные не смешиваются с настоящими
    /// и стираются одной строкой при отладке.
    private let defaults: UserDefaults

    private enum Key {
        static let ownID = "fake.ownProfileID"
        static let inviteCode = "fake.inviteCode"
        static let inviteExpires = "fake.inviteExpiresAt"
        static let inviteCreated = "fake.inviteCreatedAt"
        static let partner = "fake.partner"
        static let published = "fake.publishedSnapshot"
    }

    private var flakyCounter = 0

    init(defaults: UserDefaults = UserDefaults(suiteName: "partner.fake") ?? .standard) {
        self.defaults = defaults
    }

    // MARK: - PartnerSyncing

    func prepare() async throws -> String {
        try await simulateCall()
        if let existing = defaults.string(forKey: Key.ownID) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Key.ownID)
        return fresh
    }

    func publish(_ snapshot: OwnSnapshot) async throws {
        try await simulateCall()
        defaults.set(snapshot.nickname, forKey: Key.published)

        // Если включено зеркало — напарник повторяет мои числа. Это лучший
        // способ показать, что цепочка «отметился → уехало → видно» работает.
        if mirrorsMe, var partner = storedPartner {
            partner.currentStreak = snapshot.currentStreak
            partner.goalDays = snapshot.goalDays
            partner.lastCheckInDay = snapshot.lastCheckInDay
            partner.updatedAt = Date()
            store(partner)
        }
    }

    func createInvite() async throws -> PartnerInvite {
        try await simulateCall()
        guard storedPartner == nil else { throw PartnerSyncError.alreadyPaired }

        let invite = PartnerInvite(code: PartnerCode.generate(),
                                   expiresAt: Date().addingTimeInterval(15 * 60))
        defaults.set(invite.code, forKey: Key.inviteCode)
        defaults.set(invite.expiresAt, forKey: Key.inviteExpires)
        defaults.set(Date(), forKey: Key.inviteCreated)
        return invite
    }

    func cancelInvite() async throws {
        try await simulateCall()
        clearInvite()
    }

    func pollInviteAcceptance() async throws -> PartnerProfile? {
        try await simulateCall()
        guard let created = defaults.object(forKey: Key.inviteCreated) as? Date else { return nil }
        guard Date().timeIntervalSince(created) >= acceptanceDelay else { return nil }

        clearInvite()
        let partner = Self.samplePartner()
        store(partner)
        return partner
    }

    func redeem(code: String) async throws -> PartnerProfile {
        try await simulateCall()

        if scenario == .codeNotFound { throw PartnerSyncError.codeNotFound }
        guard storedPartner == nil else { throw PartnerSyncError.alreadyPaired }
        guard PartnerCode.isComplete(code) else { throw PartnerSyncError.codeNotFound }

        // Свой же код принимать нельзя — эту ветку тоже надо уметь посмотреть.
        if let mine = defaults.string(forKey: Key.inviteCode), mine == code {
            throw PartnerSyncError.codeIsMine
        }

        clearInvite()
        let partner = Self.samplePartner()
        store(partner)
        return partner
    }

    func fetchPartner() async throws -> PartnerProfile? {
        try await simulateCall()
        if scenario == .partnerLeft, storedPartner != nil {
            clearPartner()
            throw PartnerSyncError.partnerGone
        }
        return storedPartner
    }

    func unpair() async throws {
        try await simulateCall()
        clearPartner()
        clearInvite()
        // Ротация идентификатора — в настоящем CloudKit это и есть отзыв
        // доступа, поэтому заглушка ведёт себя так же.
        defaults.set(UUID().uuidString, forKey: Key.ownID)
    }

    // MARK: - Внутреннее

    private func simulateCall() async throws {
        try? await Task.sleep(for: latency)

        if scenario == .noAccount { throw PartnerSyncError.iCloudUnavailable }
        if scenario == .flaky {
            flakyCounter += 1
            if flakyCounter % 3 == 0 { throw PartnerSyncError.network }
        }
    }

    private static func samplePartner() -> PartnerProfile {
        PartnerProfile(id: UUID().uuidString,
                       nickname: "Марк",
                       currentStreak: 12,
                       goalDays: 30,
                       lastCheckInDay: DayKey.today(),
                       updatedAt: Date())
    }

    private var storedPartner: PartnerProfile? {
        guard let data = defaults.data(forKey: Key.partner) else { return nil }
        return try? JSONDecoder().decode(PartnerProfile.self, from: data)
    }

    private func store(_ profile: PartnerProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Key.partner)
        }
    }

    private func clearPartner() {
        defaults.removeObject(forKey: Key.partner)
    }

    private func clearInvite() {
        defaults.removeObject(forKey: Key.inviteCode)
        defaults.removeObject(forKey: Key.inviteExpires)
        defaults.removeObject(forKey: Key.inviteCreated)
    }

    // MARK: - Отладка

    private var mirrorsMe: Bool {
        get { defaults.bool(forKey: "fake.mirrorsMe") }
        set { defaults.set(newValue, forKey: "fake.mirrorsMe") }
    }

    #if DEBUG
    /// Заставить «напарника» повторять мои числа — сквозная демонстрация
    /// без сети: нажал «Я ДЕРЖУСЬ» на главной, увидел это на его иконке.
    func debugSetMirrorsMe(_ on: Bool) { mirrorsMe = on }

    func debugSetPartner(streak: Int? = nil, holdingToday: Bool? = nil, staleHours: Int? = nil) {
        guard var partner = storedPartner else { return }
        if let streak { partner.currentStreak = streak }
        if let holdingToday { partner.lastCheckInDay = holdingToday ? DayKey.today() : nil }
        if let staleHours { partner.updatedAt = Date().addingTimeInterval(-Double(staleHours) * 3600) }
        store(partner)
    }

    func debugReset() {
        [Key.ownID, Key.inviteCode, Key.inviteExpires,
         Key.inviteCreated, Key.partner, Key.published, "fake.mirrorsMe"]
            .forEach { defaults.removeObject(forKey: $0) }
    }
    #endif
}
