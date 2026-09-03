//
//  PartnerChat.swift
//  NoFap
//
//  Переписка с напарником. Чат открытый — писать можно что угодно, но
//  рядом лежат быстрые ответы: в момент тяги набирать текст физически
//  тяжело, а тапнуть одну кнопку — нет.
//

import Foundation

struct PartnerMessage: Codable, Sendable, Equatable, Identifiable {

    enum Kind: String, Codable, Sendable {
        case text       // обычное сообщение
        case sos        // «мне трудно» — сигнал в момент тяги
        case support    // быстрая поддержка одним тапом
    }

    let id: String
    let kind: Kind
    let text: String

    /// Уже разрешено слоем синхронизации: он знает мой идентификатор,
    /// а интерфейсу остаётся только решить, с какой стороны рисовать.
    let isMine: Bool

    let sentAt: Date
}

extension PartnerMessage {

    /// Сигнал тяги выделяется и по смыслу, и визуально — это не реплика
    /// в разговоре, а просьба о помощи.
    var isSignal: Bool { kind == .sos }

    static func mine(_ text: String, kind: Kind = .text) -> PartnerMessage {
        PartnerMessage(id: UUID().uuidString,
                       kind: kind,
                       text: text,
                       isMine: true,
                       sentAt: Date())
    }
}

enum ChatPresets {

    /// Текст сигнала фиксирован: он должен читаться одинаково у обоих и не
    /// требовать раздумий от того, кому и так тяжело.
    static let sos = "Мне сейчас трудно"

    /// Ответы на сигнал. Короткие, без советов и морали — задача не научить,
    /// а обозначить присутствие.
    static let support = [
        "Я рядом",
        "Держись, это пройдёт",
        "Позвони мне",
        "Выйди прогуляться",
        "Ты уже проходил это"
    ]

    /// Ограничение длины: чат — для поддержки, а не для переписки на экран.
    static let maxLength = 500
}
