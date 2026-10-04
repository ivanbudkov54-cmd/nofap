//
//  BuddyError.swift
//  NoFap
//

import Foundation

enum BuddyError: LocalizedError, Equatable {
    case invalidCodeLength
    case unauthorized
    case userNotFound
    case cannotPairWithSelf
    case buddyAlreadyPaired

    var errorDescription: String? {
        switch self {
        case .invalidCodeLength, .userNotFound:
            "Код не найден. Проверьте правильность ввода."
        case .unauthorized:
            "Сессия не найдена. Откройте приложение ещё раз при наличии сети."
        case .cannotPairWithSelf:
            "Нельзя ввести свой собственный код."
        case .buddyAlreadyPaired:
            "Этот пользователь уже имеет напарника."
        }
    }
}
