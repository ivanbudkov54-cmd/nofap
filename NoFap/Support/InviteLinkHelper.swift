//
//  InviteLinkHelper.swift
//  NoFap
//

import Foundation

enum InviteLinkHelper {
    /// Публичная ссылка, которой делятся с напарником.
    static func generateInviteURL(for code: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "nofap.app"
        components.path = "/invite"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url ?? URL(string: "https://nofap.app/invite?code=\(code)")!
    }

    /// Схема, которую приложение открывает само: nofap://buddy/join?code=
    static func appInviteURL(for code: String) -> URL {
        var components = URLComponents()
        components.scheme = "nofap"
        components.host = "buddy"
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url ?? URL(string: "nofap://buddy/join?code=\(code)")!
    }

    static func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    static func shareText(for code: String) -> String {
        let link = generateInviteURL(for: code).absoluteString
        return """
        Брат, я держу стрик чистой дисциплины. Становись моим напарником по ссылке:
        \(link)

        Или введи мой код вручную в приложении: \(code)
        """
    }

    /// Достаёт 6-значный код из https://nofap.app/invite?code= или nofap://buddy/join?code=
    static func code(from url: URL) -> String? {
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = parts?.host?.lowercased()
        let path = url.path.lowercased()
        let isInvite = host == "invite" || host == "buddy" || path == "/invite" || path == "/join"
        guard isInvite else { return nil }
        let raw = parts?.queryItems?.first { $0.name == "code" }?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let raw, raw.count == 6, raw.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return raw
    }
}
