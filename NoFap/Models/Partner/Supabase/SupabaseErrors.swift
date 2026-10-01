//
//  SupabaseErrors.swift
//  NoFap
//
//  Перевод ошибок Supabase в словарь PartnerSyncError — общий для
//  напарника и сквада: интерфейс не должен знать ни про HTTP, ни про
//  Postgres.
//

import Foundation

/// Выполнить запрос и привести любую ошибку к PartnerSyncError.
@MainActor
func supabaseCall<T>(_ body: () async throws -> T) async throws -> T {
    do {
        return try await body()
    } catch let error as PartnerSyncError {
        throw error
    } catch SupabaseError.rejected(let code) {
        throw PartnerSyncError(supabaseCode: code)
    } catch SupabaseAuthError.notConfigured {
        throw PartnerSyncError.other(String(localized: "Сервер напарника не настроен."))
    } catch SupabaseError.denied {
        throw PartnerSyncError.other(String(localized: "Сервер отклонил запрос. Попробуй позже."))
    } catch {
        throw PartnerSyncError.network
    }
}

extension PartnerSyncError {

    /// Коды — те, что поднимают функции в supabase/schema.sql.
    init(supabaseCode code: String) {
        self = switch code {
        case "code_not_found":                 .codeNotFound
        case "code_expired":                   .codeExpired
        case "code_already_used":              .codeAlreadyUsed
        case "code_is_mine":                   .codeIsMine
        case "already_paired":                 .alreadyPaired
        case "partner_gone", "not_in_squad":   .partnerGone
        case "squad_full":                     .squadFull
        case "already_in_squad":               .alreadyInSquad
        default:                               .network
        }
    }
}
