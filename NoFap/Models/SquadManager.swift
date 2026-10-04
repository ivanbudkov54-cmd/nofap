//
//  SquadManager.swift
//  NoFap
//

import Foundation

@MainActor
@Observable
final class SquadManager {
    private let client = SupabaseClient()
    private(set) var squad: SquadModel?
    private(set) var isLoading = false
    var errorMessage: String?

    var totalStreakDays: Int { squad?.totalStreakDays ?? 0 }

    func fetchSquadDetails() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.ensureSession()
            squad = try await client.fetchUserSquad()
            errorMessage = nil
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    func createSquad(name: String) async {
        do {
            try await client.ensureSession()
            _ = try await client.createSquad(name: name)
            await refresh()
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    func joinSquad(code: String) async {
        do {
            try await client.ensureSession()
            try await client.joinSquad(code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            await refresh()
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    func leaveSquad() async {
        do {
            try await client.ensureSession()
            try await client.leaveSquad()
            squad = nil
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    private static func message(from error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("could not find the function") || lower.contains("pgrst202") {
            return "Создание сквада ещё не включено на сервере. В пустом SQL Editor выполни файл supabase/fix_buddy_system.sql и нажми Run and enable RLS."
        }
        if lower.contains("squad not found") || lower.contains("не найден") {
            return "Код сквада не найден. Проверьте правильность ввода."
        }
        if lower.contains("нет подключения") || lower.contains("offline") {
            return "Нет связи с сервером. Попробуй ещё раз."
        }
        return text
    }
}
