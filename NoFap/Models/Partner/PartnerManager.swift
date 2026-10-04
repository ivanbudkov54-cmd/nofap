//
//  PartnerManager.swift
//  NoFap
//
//  Состояние напарника для интерфейса. Форма намеренно повторяет
//  BlockingManager: вложенный enum State, private(set) state, refresh()
//  и async-методы, кладущие ошибку в состояние, а не бросающие её во вью.
//

import Foundation

@Observable
@MainActor
final class PartnerManager {

    enum State: Equatable {
        case unknown                    // ещё не спрашивали бэкенд
        case solo                       // напарника нет
        case inviting(PartnerInvite)    // код создан, ждём
        case paired(PartnerProfile)
        case failed(String)
    }

    private(set) var state: State = .unknown
    private(set) var isBusy = false

    /// Самоназвание. Не имя из iCloud и не имя устройства — только то,
    /// что человек вписал сам.
    private(set) var nickname: String

    private(set) var messages: [PartnerMessage] = []
    private(set) var isSending = false
    private(set) var foundPartner: PartnerProfile?
    var codeError: String?
    private var pendingCode: String?

    private let sync: any PartnerSyncing
    private let defaults: UserDefaults
    private var pollTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?

    /// Последнее успешно отправленное состояние — чтобы не слать одно и то же.
    private var lastPushed: OwnSnapshot?

    var partner: PartnerProfile? {
        if case .paired(let profile) = state { return profile }
        return nil
    }

    var isPaired: Bool { partner != nil }

    var isInviting: Bool {
        if case .inviting = state { return true }
        return false
    }

    init(sync: (any PartnerSyncing)? = nil, defaults: UserDefaults = .standard) {
        self.sync = sync ?? PartnerSyncFactory.make()
        self.defaults = defaults
        self.nickname = defaults.string(forKey: "partnerNickname") ?? Self.suggestNickname()
    }

    // MARK: - Прозвище

    /// Предлагаем выдуманное имя вместо пустого поля — это заметно снижает
    /// шанс, что человек впишет настоящее.
    private static func suggestNickname() -> String {
        String(localized: "Сизиф-\(Int.random(in: 100...999))")
    }

    func setNickname(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...16).contains(trimmed.count) else { return }
        nickname = trimmed
        defaults.set(trimmed, forKey: "partnerNickname")
    }

    // MARK: - Жизненный цикл

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await sync.prepare()
            if let profile = try await sync.fetchPartner() {
                state = .paired(profile)
            } else if !isInviting {
                state = .solo
            }
        } catch let error as PartnerSyncError {
            state = error == .partnerGone ? .solo : .failed(error.message)
        } catch let error as SupabaseError {
            state = .failed(error.errorDescription ?? PartnerSyncError.network.message)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? PartnerSyncError.network.message)
        }
    }

    func createInvite() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let invite = try await sync.createInvite()
            state = .inviting(invite)
            startPolling()
        } catch let error as PartnerSyncError {
            state = .failed(error.message)
        } catch {
            state = .failed(Self.pairingMessage(from: error))
        }
    }

    func cancelInvite() async {
        stopPolling()
        try? await sync.cancelInvite()
        state = .solo
    }

    func preview(code: String) async {
        isBusy = true
        defer { isBusy = false }
        codeError = nil
        foundPartner = nil
        let normalized = PartnerCode.normalize(code)
        pendingCode = normalized
        do {
            foundPartner = try await sync.preview(code: normalized)
        } catch {
            codeError = Self.pairingMessage(from: error)
        }
    }

    func confirmRedeem() async {
        guard let code = pendingCode else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let profile = try await sync.redeem(code: code)
            stopPolling()
            foundPartner = nil
            pendingCode = nil
            codeError = nil
            state = .paired(profile)
        } catch {
            codeError = Self.pairingMessage(from: error)
        }
    }

    private static func pairingMessage(from error: Error) -> String {
        if let buddy = error as? BuddyError, let text = buddy.errorDescription { return text }
        if let partner = error as? PartnerSyncError { return partner.message }
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("не найден") || lower.contains("not found") {
            return BuddyError.userNotFound.errorDescription ?? text
        }
        if lower.contains("самим собой") || lower.contains("self") {
            return BuddyError.cannotPairWithSelf.errorDescription ?? text
        }
        if lower.contains("уже") || lower.contains("paired") {
            return BuddyError.buddyAlreadyPaired.errorDescription ?? text
        }
        return text
    }

    func unpair() async {
        stopPolling()
        stopWatchingChat()
        try? await sync.unpair()
        lastPushed = nil
        messages = []
        state = .solo
    }

    // MARK: - Переписка

    func loadMessages() async {
        guard isPaired else { return }
        messages = (try? await sync.fetchMessages()) ?? messages
    }

    /// Пока экран чата открыт, подтягиваем ответы. Без пушей это
    /// единственный способ увидеть сообщение, не выходя и не возвращаясь.
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
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(ChatPresets.maxLength))
        guard !text.isEmpty, isPaired, !isSending else { return false }

        isSending = true
        defer { isSending = false }

        do {
            let sent = try await sync.send(text, kind: kind)
            // Показываем сразу, не дожидаясь следующего опроса.
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            return true
        } catch let error as PartnerSyncError {
            state = error == .partnerGone ? .solo : .failed(error.message)
            return false
        } catch {
            state = .failed(PartnerSyncError.network.message)
            return false
        }
    }

    // MARK: - Публикация своего состояния

    /// Вызывается при любом изменении стрика. Сетевые ошибки здесь молчат:
    /// неудачная отправка не должна выбрасывать баннер поверх поздравления
    /// с достижением цели.
    func push(from streak: StreakManager) async {
        guard isPaired || isInviting else { return }

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
            lastPushed = nil    // попробуем ещё раз при следующем изменении
        }
    }

    // MARK: - Ожидание, пока код примут

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { return }

                if case .inviting(let invite) = self.state, invite.isExpired {
                    await self.cancelInvite()
                    return
                }
                guard let profile = try? await self.sync.pollInviteAcceptance() else { continue }
                self.state = .paired(profile)
                return
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    #if DEBUG
    var fake: LocalFakePartnerSync? { sync as? LocalFakePartnerSync }
    #endif
}
