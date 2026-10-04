//
//  BuddyManager.swift
//  NoFap
//

import Foundation

@MainActor
@Observable
final class BuddyManager {
    private let client = SupabaseClient()
    private(set) var currentBuddy: UserProfile?
    private(set) var foundBuddy: UserProfile?
    private var pendingPairCode: String?
    private(set) var myProfile: UserProfile?
    private(set) var chatMessages: [ChatMessage] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var pendingBuddyCode: String?
    private var watch: Task<Void, Never>?
    private var chatWatch: Task<Void, Never>?

    var inviteCode: String? { myProfile?.inviteCode }

    /// Только код, который уже записан в profiles. Локальная подмена не создаётся.
    func codeForSharing() -> String? {
        myProfile?.inviteCode
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.ensureSession()
            myProfile = try await client.ensureInviteCode()
            currentBuddy = try await client.fetchCurrentBuddy()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard let code = InviteLinkHelper.code(from: url) else { return }
        pendingBuddyCode = code
    }

    func noteCodeChanged(_ raw: String) {
        let sanitized = PartnerCode.normalize(raw)
        guard sanitized != pendingPairCode else { return }
        foundBuddy = nil
        pendingPairCode = nil
        errorMessage = nil
    }

    func searchBuddy(inputCode: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        foundBuddy = nil
        let sanitized = PartnerCode.normalize(inputCode)
        guard sanitized.count == 6 else {
            errorMessage = BuddyError.invalidCodeLength.errorDescription
            return
        }
        do {
            try await client.ensureSession()
            guard let currentUserId = client.currentUserId() else { throw BuddyError.unauthorized }
            let target = try await client.lookupBuddy(code: sanitized)
            guard target.id != currentUserId else { throw BuddyError.cannotPairWithSelf }
            if target.buddyId != nil { throw BuddyError.buddyAlreadyPaired }
            foundBuddy = target
            pendingPairCode = sanitized
        } catch let error as BuddyError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    func confirmPair() async {
        guard let code = pendingPairCode else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.ensureSession()
            currentBuddy = try await client.pairWithBuddy(code: code)
            foundBuddy = nil
            pendingPairCode = nil
            pendingBuddyCode = nil
            errorMessage = nil
        } catch let error as BuddyError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    private static func message(from error: Error) -> String {
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

    /// Громкий сигнал напарнику. Вызывать только после проверки Pro.
    func sendSOSAlert(isPro: Bool) async {
        guard isPro else {
            errorMessage = "Оповещение напарника при SOS доступно в Pro-версии"
            return
        }
        do {
            try await client.ensureSession()
            try await client.pingBuddySOS()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    func sendMessage(text: String) async {
        guard let receiver = currentBuddy?.id else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await client.ensureSession()
            try await client.sendBuddyMessage(to: receiver, text: trimmed)
            chatMessages = try await client.fetchMessages()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    /// Живая лента: пока чат открыт, новые сообщения подтягиваются без ручного обновления.
    func subscribeToRealtimeChat() {
        guard chatWatch == nil else { return }
        chatWatch = Task { [weak self] in
            while !Task.isCancelled {
                await self?.reloadMessages()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopRealtimeChat() {
        chatWatch?.cancel()
        chatWatch = nil
    }

    func startWatching() {
        guard watch == nil else { return }
        watch = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    func stopWatching() {
        watch?.cancel()
        watch = nil
    }

    private func reloadMessages() async {
        do {
            try await client.ensureSession()
            chatMessages = try await client.fetchMessages()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
