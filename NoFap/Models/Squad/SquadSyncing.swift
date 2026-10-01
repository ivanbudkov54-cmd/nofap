//
//  SquadSyncing.swift
//  NoFap
//
//  Сквад — группа до четырёх человек (ты и ещё трое): видят дни друг друга
//  и пишут в общий чат. Отдельно от напарника: напарник — один на один,
//  у него своя переписка, и в сквад он не попадает автоматически.
//
//  Как и у напарника, экраны знают только этот протокол — за ним стоит
//  локальная заглушка или Supabase.
//

import Foundation

enum SquadLimits {
    /// Ты + трое. Вместе с напарником на карточке прогресса пять человек.
    static let maxMembers = 4

    /// Приглашение многоразовое: одну ссылку отправляют сразу нескольким,
    /// поэтому живёт дольше одноразового кода напарника.
    static let inviteLifetime: TimeInterval = 24 * 3600
}

/// Состояние сквада, каким его видит эта сторона.
struct SquadSnapshot: Equatable, Sendable {
    /// Остальные участники, без меня.
    var members: [PartnerProfile]
    /// Открытое приглашение, если есть.
    var invite: PartnerInvite?
}

protocol SquadSyncing: AnyObject, Sendable {

    /// nil — я не в скваде.
    func fetchSquad() async throws -> SquadSnapshot?

    /// Создаёт приглашение; если сквада ещё нет — создаёт и сквад.
    func createInvite() async throws -> PartnerInvite

    func cancelInvite() async throws

    func join(code: String) async throws -> SquadSnapshot

    func leave() async throws

    /// Мои прозвище и стрик для остальных участников.
    func publish(_ snapshot: OwnSnapshot) async throws

    /// Вся переписка сквада, старые сообщения первыми, с именами авторов.
    func fetchMessages() async throws -> [PartnerMessage]

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage
}

enum SquadSyncFactory {

    @MainActor
    static func make() -> any SquadSyncing {
        switch PartnerSyncFactory.backend {
        case .fake:     LocalFakeSquadSync()
        case .supabase: SupabaseSquadSync()
        }
    }
}
