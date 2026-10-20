//
//  AppInfo.swift
//  NoFap
//
//  Контакты, которые видят пользователи и Apple. Почта поддержки ещё
//  и в Resources/Legal/*.html и на сайте (репозиторий premium).
//

import Foundation

enum AppInfo {
    /// Заменить на настоящую почту поддержки перед отправкой на проверку.
    static let supportEmail = "support@example.com"

    static var supportURL: URL { URL(string: "mailto:\(supportEmail)")! }
}
