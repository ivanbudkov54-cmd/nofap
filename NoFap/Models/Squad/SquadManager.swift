//
//  SquadManager.swift
//  NoFap
//
//  Состояние сквада для интерфейса. Форма повторяет PartnerManager:
//  enum State, async-методы, ошибки — в состояние, а не в виде исключений
//  во вьюху.
//

import Foundation

@Observable
@MainActor
final class SquadManager {

    enum State: Equatable {
        case unknown
        case none                       // не в скваде
        case active(SquadSnapshot)
        case failed(String)
    }

    private(set) var state: State = .unknown
    private(set) var isBusy = false
    private(set) var messages: [PartnerMessage] = []
    private(set) var isSending = false

    /// Код из открытой ссылки на сквад, ждущий подтверждения — как у
    /// напарника, молча в группу не добавляем.
    var pendingCode: String?
    /// Кто зовёт по ссылке — для подписи в окне приглашения.
    var pendingInviter: String?

    private let sync: any SquadSyncing
    private var membersTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var lastPushed: OwnSnapshot?

    init(sync: (any SquadSyncing)? = nil) {
        self.sync = sync ?? SquadSyncFactory.make()
    }

    var snapshot: SquadSnapshot? {
        if case .active(let snapshot) = state { return snapshot }
        return nil
    }

    var isInSquad: Bool { snapshot != nil }

    /// Остальные участники, без меня.
    var members: [PartnerProfile] { snapshot?.members ?? [] }

    var freeSlots: Int { max(0, SquadLimits.maxMembers - 1 - members.count) }

    // MARK: - Жизненный цикл

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await load()
    }

    func createInvite() async {
        await perform { _ = try await self.sync.createInvite() }
    }

    func cancelInvite() async {
        await perform { try await self.sync.cancelInvite() }
    }

    func join(code: String) async {
        await perform { _ = try await self.sync.join(code: PartnerCode.normalize(code)) }
    }

    func leave() async {
        stopWatchingChat()
        await perform { try await self.sync.leave() }
        messages = []
        lastPushed = nil
    }

    /// Пока открыт экран со сквадом, подтягиваем, кто вступил: приглашение
    /// многоразовое, и люди приходят по одному в течение суток.
    func startWatchingMembers() {
        stopWatchingMembers()
        membersTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                await self.load()
            }
        }
    }

    func stopWatchingMembers() {
        membersTask?.cancel()
        membersTask = nil
    }

    // MARK: - Переписка

    func loadMessages() async {
        guard isInSquad else { return }
        messages = (try? await sync.fetchMessages()) ?? messages
    }

    func startWatchingChat() {
        stopWatchingChat()
        chatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadMessages()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopWatchingChat() {
        chatTask?.cancel()
        chatTask = nil
    }

    @discardableResult
    func send(_ raw: String, kind: PartnerMessage.Kind = .text) async -> Bool {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ChatPresets.maxLength))
        guard !text.isEmpty, isInSquad, !isSending else { return false }

        isSending = true
        defer { isSending = false }

        do {
            let sent = try await sync.send(text, kind: kind)
            if !messages.contains(where: { $0.id == sent.id }) { messages.append(sent) }
            return true
        } catch let error as PartnerSyncError {
            state = error == .partnerGone ? .none : .failed(error.message)
            return false
        } catch {
            state = .failed(PartnerSyncError.network.message)
            return false
        }
    }

    // MARK: - Публикация своего состояния

    /// Сетевые ошибки молчат — как у напарника, баннер поверх поздравления
    /// с целью из-за неудачной отправки был бы хуже, чем повтор позже.
    func push(from streak: StreakManager, nickname: String) async {
        guard isInSquad else { return }
        let snapshot = OwnSnapshot(
            nickname: nickname,
            currentStreak: streak.currentStreak,
            goalDays: streak.personalGoalDays,
            lastCheckInDay: streak.lastCheckinDate.map(DayKey.string(from:))
        )
        guard snapshot != lastPushed else { return }
        do {
            try await sync.publish(snapshot)
            lastPushed = snapshot
        } catch {
            lastPushed = nil
        }
    }

    // MARK: - Внутреннее

    private func load() async {
        do {
            state = try await sync.fetchSquad().map(State.active) ?? .none
        } catch let error as PartnerSyncError {
            state = .failed(error.message)
        } catch {
            state = .failed(PartnerSyncError.network.message)
        }
    }

    /// Действие, затем свежее состояние сквада с сервера — после вступления
    /// или приглашения состав мог измениться не только из-за нас.
    private func perform(_ action: @escaping () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
            await load()
        } catch let error as PartnerSyncError {
            state = .failed(error.message)
        } catch {
            state = .failed(PartnerSyncError.network.message)
        }
    }
}
