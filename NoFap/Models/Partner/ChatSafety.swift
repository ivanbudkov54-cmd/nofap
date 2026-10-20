//
//  ChatSafety.swift
//  NoFap
//
//  Безопасность переписки с напарником и в скваде — то, что Apple требует
//  от любого приложения с общением между людьми (App Review 1.2):
//  - правила общения, с которыми соглашаются до первого сообщения;
//  - фильтр: ссылки и грубые слова не уходят;
//  - жалоба на сообщение — в таблицу chat_reports (supabase/06_chat_safety.sql),
//    разбираем в течение суток;
//  - блокировка: сообщения человека больше не показываются.
//

import Foundation
import os

@MainActor
@Observable
final class ChatSafety {

    static let shared = ChatSafety()

    enum Chat: String { case partner, squad }

    enum Reason: String, CaseIterable, Identifiable {
        case abuse, sexual, threat, spam, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .abuse:  String(localized: "Оскорбления")
            case .sexual: String(localized: "Откровенный контент")
            case .threat: String(localized: "Угрозы или травля")
            case .spam:   String(localized: "Спам или реклама")
            case .other:  String(localized: "Другое")
            }
        }
    }

    private(set) var rulesAccepted: Bool
    private(set) var blockedIDs: Set<String>

    private static let log = Logger(subsystem: "Albert.lvan.NoFap", category: "chat-safety")
    private let db = SupabaseClient(session: .shared)
    private let defaults = UserDefaults.standard

    private enum Key {
        static let rules = "chat.rulesAccepted"
        static let blocked = "chat.blockedIDs"
    }

    private init() {
        rulesAccepted = defaults.bool(forKey: Key.rules)
        blockedIDs = Set(defaults.stringArray(forKey: Key.blocked) ?? [])
    }

    func acceptRules() {
        rulesAccepted = true
        defaults.set(true, forKey: Key.rules)
    }

    // MARK: - Фильтр

    /// Ссылки и откровенная брань. Быстрые ответы и сигнал проходят всегда —
    /// их текст фиксирован.
    func isAllowed(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.range(of: #"(https?://|www\.|t\.me/|\b[a-z0-9-]+\.(com|ru|net|org|io|me|tv|xxx)\b)"#,
                       options: .regularExpression) != nil {
            return false
        }
        return !Self.blockedRoots.contains { lower.contains($0) }
    }

    private static let blockedRoots = [
        "хуй", "хуе", "хуё", "хуя", "пизд", "ебат", "ебан", "ёбан", "ебал", "ебло", "уеб", "уёб",
        "бляд", "блят", "сука", "суки", "мудак", "мудил", "пидор", "пидар", "шлюх", "гандон",
        "fuck", "shit", "bitch", "cunt", "nigger", "faggot", "porn", "порно", "xxx"
    ]

    // MARK: - Жалоба и блокировка

    /// true — жалоба записана на сервере.
    @discardableResult
    func report(_ message: PartnerMessage, reason: Reason, in chat: Chat) async -> Bool {
        do {
            try await db.insert("chat_reports", [[
                "message_id": message.id,
                "chat": chat.rawValue,
                "reported_user": message.senderID,
                "reason": reason.rawValue,
                "body": String(message.text.prefix(500))
            ]])
            return true
        } catch {
            Self.log.error("report failed: \(error.localizedDescription)")
            return false
        }
    }

    func block(_ userID: String) async {
        blockedIDs.insert(userID)
        defaults.set(Array(blockedIDs), forKey: Key.blocked)
        // Копия на сервере — чтобы видеть, кого блокируют, при разборе жалоб.
        // Не получилось — не страшно: скрываем всё равно на телефоне.
        try? await db.insert("user_blocks", [["blocked": userID]], upsert: true)
    }

    func isBlocked(_ message: PartnerMessage) -> Bool {
        guard !message.isMine, let id = message.senderID else { return false }
        return blockedIDs.contains(id)
    }
}
