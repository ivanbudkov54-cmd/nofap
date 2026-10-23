//
//  AppInfo.swift
//  NoFap
//
//  Контакты, которые видят пользователи и Apple. Почта поддержки ещё
//  и в Resources/Legal/*.html и на сайте (репозиторий premium).
//

import Foundation

enum AppInfo {
    /// Почта поддержки — её видят пользователи и Apple.
    static let supportEmail = "stopfapsupport@gmail.com"

    static var supportURL: URL { URL(string: "mailto:\(supportEmail)")! }
}
