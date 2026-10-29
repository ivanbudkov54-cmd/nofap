//
//  AppRouter.swift
//  NoFap
//
//  Общий выбор вкладки, чтобы щит стрика мог открыть дневник и разбор срыва
//  с главного экрана.
//

import Foundation

@MainActor
@Observable
final class AppRouter {
    var selectedTab = 0
    var openRelapseReview = false
    /// Дата щита до активации. Если разбор закрыли, её возвращаем.
    var freezeDateBeforeShield: Date?
    var toast: String?

    static let homeTab = 0
    static let diaryTab = 2
    static let knowledgeTab = 3
    static let shieldPrompt = "Что стало триггером и что ты сделаешь чтобы в дальнейшем избежать срыва?"
}

/// Просьба открыть экран снаружи: SOS с экрана блокировки или по ссылке
/// nofap://sos, вкладку — по нажатию на напоминание. Синглтон, потому что
/// уведомление может прийти, пока RestoreGate ещё не создал менеджеры, и
/// даже до первого окна.
@MainActor
@Observable
final class OpenRequest {
    static let shared = OpenRequest()
    var sos = false
    var destination: NotificationDestination?
    /// Открыть экспресс-чекин, когда дневник появится на экране.
    var checkIn = false
    /// Magic link открыл приложение и сессия уже записана.
    var emailAuthCompleted = false
    /// Ссылка пришла, пока RestoreGate ещё на экране, или приложение только что поднялось.
    var incomingURL: URL?
}
