//
//  PartnerModels.swift
//  NoFap
//
//  Всё, что двое видят друг о друге. Список полей — это и есть граница
//  приватности: чего здесь нет, то физически не может уехать с телефона.
//  Нет истории по дням, нет рекорда, нет отметки «был срыв».
//

import Foundation

/// Состояние напарника, каким его видит эта сторона.
struct PartnerProfile: Codable, Sendable, Equatable, Identifiable {
    let id: String                  // UUID; в CloudKit это же recordName
    var nickname: String
    var currentStreak: Int
    var goalDays: Int

    /// День последней отметки, "yyyy-MM-dd". Намеренно не Bool:
    /// булев флаг «отметился сегодня» протухает в полночь, если напарник
    /// давно не открывал приложение и некому его обновить.
    var lastCheckInDay: String?

    var updatedAt: Date
}

extension PartnerProfile {

    /// Отметился именно сегодня — по календарю того, кто смотрит.
    var isHoldingToday: Bool {
        guard let day = lastCheckInDay else { return false }
        return day == DayKey.today()
    }

    /// Данные давно не обновлялись: напарник не заходил в приложение.
    /// Показываем это честно, чтобы число не выдавали за свежее.
    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 36 * 3600
    }
}

/// То, что я публикую о себе. Отдельный тип от PartnerProfile — чтобы их
/// нельзя было случайно перепутать местами в вызове.
struct OwnSnapshot: Sendable, Equatable {
    var nickname: String
    var currentStreak: Int
    var goalDays: Int
    var lastCheckInDay: String?
}

/// Код-приглашение с ограниченным сроком жизни.
struct PartnerInvite: Sendable, Equatable {
    let code: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }

    /// Показываем как «K7M 4QP», а храним и вводим без пробела.
    var grouped: String {
        guard code.count == PartnerCode.length else { return code }
        return code.prefix(3) + " " + code.suffix(3)
    }
}

enum PartnerCode {

    static let length = 6

    /// Без I, O, 0, 1 — их путают, переписывая код с чужого экрана.
    /// 32 символа, 6 знаков — больше миллиарда вариантов против миллиона
    /// у шестизначного числа, которое перебирается за вечер.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    /// Приводит ввод к каноническому виду: заглавные, без посторонних знаков,
    /// не длиннее нужного.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) }.prefix(length))
    }

    static func isComplete(_ code: String) -> Bool {
        code.count == length
    }
}

enum PartnerSyncError: Error, Equatable, Sendable {
    case iCloudUnavailable
    case network
    case codeNotFound
    case codeExpired
    case codeAlreadyUsed
    case codeIsMine
    case alreadyPaired
    case partnerGone
    case other(String)

    /// Текст для человека живёт рядом с ошибкой, а не во вьюхе: так
    /// невозможно добавить новый случай и забыть его перевести.
    var message: String {
        switch self {
        case .iCloudUnavailable:
            "Нужен вход в iCloud — без него напарник не работает."
        case .network:
            "Нет связи. Попробуй ещё раз."
        case .codeNotFound:
            "Такого кода нет. Проверь буквы."
        case .codeExpired:
            "Код истёк. Попроси новый."
        case .codeAlreadyUsed:
            "Этот код уже использовали."
        case .codeIsMine:
            "Это твой собственный код."
        case .alreadyPaired:
            "У тебя уже есть напарник."
        case .partnerGone:
            "Напарник разорвал связь."
        case .other(let text):
            text
        }
    }
}
