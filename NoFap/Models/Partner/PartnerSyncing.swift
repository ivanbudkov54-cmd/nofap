//
//  PartnerSyncing.swift
//  NoFap
//
//  Единственное, что интерфейс знает о синхронизации. За этим протоколом
//  стоит либо локальная заглушка, либо Firebase — экраны при этом не
//  меняются.
//

import Foundation

/// Протокол намеренно неизолирован: изоляцию выбирает та сторона, что его
/// реализует, а `@MainActor` на самом протоколе навязал бы её всем.
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
    /// в чужой профиль писать нельзя, поэтому присоединившийся лишь
    /// отмечается в приглашении, а связь у себя закрепляет пригласивший.
    func pollInviteAcceptance() async throws -> PartnerProfile?

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
    case fake
    case firebase
}

enum PartnerSyncFactory {

    /// Firebase, а не CloudKit: работает и на Android, и не требует платного
    /// Apple Developer. Пока ключи проекта не вписаны в FirebaseConfig,
    /// интерфейс живёт на заглушке.
    static var backend: PartnerBackend {
        FirebaseConfig.isConfigured ? .firebase : .fake
    }

    @MainActor
    static func make() -> any PartnerSyncing {
        switch backend {
        case .fake:     LocalFakePartnerSync()
        case .firebase: FirebasePartnerSync()
        }
    }
}
