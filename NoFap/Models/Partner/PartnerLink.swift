//
//  PartnerLink.swift
//  NoFap
//
//  Ссылка-приглашение в напарники. Делимся веб-страницей
//  (`https://…/join/?c=K7M4QP`): её мессенджеры делают кликабельной, а
//  своя схема `nofap://` — нет. Страница уже сама открывает приложение
//  по `nofap://join/K7M4QP`, а если его нет — показывает код.
//
//  Исходник страницы — репозиторий `join` на GitHub Pages. Свой домен
//  потом меняется только в `webPage`.
//

import Foundation

enum PartnerLink {

    static let scheme = "nofap"

    static let webPage = "https://ivanbudkov54-cmd.github.io/join/"

    static func url(for code: String) -> URL {
        URL(string: "\(webPage)?c=\(code)")!
    }

    /// Код из ссылки или nil, если это не приглашение. Понимает и
    /// `nofap://join/X` (так страница открывает приложение), и
    /// `…/join/?c=X` — на случай, когда веб-ссылка начнёт открывать
    /// приложение напрямую (universal links).
    static func code(from url: URL) -> String? {
        let fromQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "c" }?.value

        let parts = ([url.host() ?? ""] + url.pathComponents).filter { $0 != "/" && !$0.isEmpty }
        let fromPath = parts.firstIndex(of: "join").flatMap { $0 + 1 < parts.count ? parts[$0 + 1] : nil }

        guard let raw = fromQuery ?? fromPath else { return nil }
        let code = PartnerCode.normalize(raw)
        return PartnerCode.isComplete(code) ? code : nil
    }
}
