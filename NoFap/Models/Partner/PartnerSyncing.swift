//
//  PartnerSyncing.swift
//  NoFap
//
//  Единственное, что интерфейс знает о синхронизации. За этим протоколом
//  сейчас стоит локальная заглушка, а позже встанет CloudKit — экраны при
//  этом не меняются.
//

import Foundation

/// Протокол намеренно неизолирован: изоляцию выбирает та сторона, что его
/// реализует. Локальной заглушке главный актор подходит, а будущему
/// CloudKit-клиенту — нет: `@MainActor` на самом протоколе пригвоздил бы его
/// сетевые запросы к главному актору.
protocol PartnerSyncing: AnyObject, Sendable {

    /// Убедиться, что бэкенд доступен и мой профиль существует.
    /// Возвращает мой собственный идентификатор, создавая его при первом вызове.
    func prepare() async throws -> String

    /// Опубликовать своё состояние. Вызывается часто, должно быть идемпотентным.
    func publish(_ snapshot: OwnSnapshot) async throws

    func createInvite() async throws -> PartnerInvite

    /// Отозвать свой код. На сервере это единственный настоящий отзыв —
    /// проверки срока на стороне клиента недостаточно.
    func cancelInvite() async throws

    /// Принял ли кто-нибудь мой код. nil — ещё нет.
    ///
    /// Отдельный метод для стороны пригласившего существует не от красоты:
    /// в публичной базе CloudKit нельзя писать в чужую запись, поэтому
    /// присоединившийся не может сам вписать себя в приглашение — он
    /// оставляет свою запись, а пригласивший её забирает.
    func pollInviteAcceptance() async throws -> PartnerProfile?

    /// Найти профиль по коду, не записывая связь.
    func preview(code: String) async throws -> PartnerProfile

    /// Ввести чужой код и связаться. Сторона присоединяющегося.
    func redeem(code: String) async throws -> PartnerProfile

    /// Свежее состояние напарника. nil — напарника нет.
    /// Бросает `.partnerGone`, если связь разорвали с той стороны.
    func fetchPartner() async throws -> PartnerProfile?

    /// Разорвать связь. Обязана ротировать мой идентификатор: иначе бывший
    /// напарник навсегда сохраняет возможность читать мой профиль.
    func unpair() async throws

    // MARK: - Переписка

    /// Вся переписка, старые сообщения первыми.
    func fetchMessages() async throws -> [PartnerMessage]

    func send(_ text: String, kind: PartnerMessage.Kind) async throws -> PartnerMessage
}

enum PartnerBackend: String {
    case supabase
}

enum PartnerSyncFactory {

    /// Напарник ищется только в Supabase по invite_code. Локальная заглушка не используется.
    static var backend: PartnerBackend { .supabase }

    @MainActor
    static func make() -> any PartnerSyncing {
        SupabasePartnerSync()
    }
}
