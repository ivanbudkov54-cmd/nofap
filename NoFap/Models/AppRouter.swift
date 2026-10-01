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

    static let diaryTab = 1
    static let shieldPrompt = "Что стало триггером и что ты сделаешь чтобы в дальнейшем избежать срыва?"
}
