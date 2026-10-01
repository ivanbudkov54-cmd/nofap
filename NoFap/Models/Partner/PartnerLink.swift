//
//  PartnerLink.swift
//  NoFap
//
//  Ссылки-приглашения: в напарники и в сквад. Делимся веб-страницей
//  (`https://…/join/?c=КОД` или `?s=КОД`): её мессенджеры делают
//  кликабельной, а своя схема `nofap://` — нет. Страница сама открывает
//  приложение по `nofap://join/КОД` или `nofap://squad/КОД`, а если его
//  нет — показывает код.
//
//  Исходник страницы — репозиторий `join` на GitHub Pages. Свой домен
//  потом меняется только в `webPage`.
//

import Foundation

enum PartnerLink {

    enum Kind {
        case partner, squad

        /// Хост в `nofap://…` и сегмент пути у будущих universal links.
        fileprivate var path: String { self == .partner ? "join" : "squad" }
        /// Параметр на веб-странице.
        fileprivate var query: String { self == .partner ? "c" : "s" }
    }

    static let scheme = "nofap"

    static let webPage = "https://ivanbudkov54-cmd.github.io/join/"

    /// Параметр с прозвищем пригласившего — чтобы в приглашении было видно,
    /// кто зовёт. Только прозвище, которое и так увидят участники.
    static let inviterQuery = "n"
    static let inviterMaxLength = 24

    static func url(for code: String, kind: Kind = .partner, from inviter: String? = nil) -> URL {
        var components = URLComponents(string: webPage)!
        components.queryItems = [URLQueryItem(name: kind.query, value: code)]
        if let name = cleanName(inviter) {
            components.queryItems?.append(URLQueryItem(name: inviterQuery, value: name))
        }
        return components.url!
    }

    struct Invite {
        let kind: Kind
        let code: String
        /// Прозвище пригласившего, если оно было в ссылке.
        let inviter: String?
    }

    /// Что это за приглашение, какой в нём код и кто зовёт, или nil, если
    /// это не приглашение. Понимает и `nofap://join/X` / `nofap://squad/X`
    /// (так страница открывает приложение), и `…/join/?c=X` / `?s=X`.
    static func invite(from url: URL) -> Invite? {
        let inviter = cleanName(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == inviterQuery }?.value)
        for kind in [Kind.partner, .squad] {
            if let code = code(from: url, kind: kind) {
                return Invite(kind: kind, code: code, inviter: inviter)
            }
        }
        return nil
    }

    /// Ссылку можно подделать руками — берём из неё только короткую
    /// строку без переводов строк, чисто для подписи.
    private static func cleanName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let name = raw.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name.prefix(inviterMaxLength))
    }

    private static func code(from url: URL, kind: Kind) -> String? {
        let fromQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == kind.query }?.value

        let parts = ([url.host() ?? ""] + url.pathComponents).filter { $0 != "/" && !$0.isEmpty }
        // У веб-ссылки «join» — папка страницы, а не признак напарника:
        // путь с кодом после неё бывает только у ссылок приложения.
        let fromPath = url.scheme == scheme
            ? parts.firstIndex(of: kind.path).flatMap { $0 + 1 < parts.count ? parts[$0 + 1] : nil }
            : nil

        guard let raw = fromQuery ?? fromPath else { return nil }
        let code = PartnerCode.normalize(raw)
        return PartnerCode.isComplete(code) ? code : nil
    }
}
