//
//  L10n.swift
//  NoFap
//

import Foundation
import SwiftUI

enum L10n {
    /// Динамический ключ: строка уже лежит в каталоге как русский оригинал.
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

extension Text {
    init(l10n key: String) {
        self.init(LocalizedStringKey(key))
    }
}

enum RegionHelper {
    /// Россия по региону устройства или по языку интерфейса.
    static var isRussia: Bool {
        if Locale.current.region?.identifier == "RU" { return true }
        return Locale.current.language.languageCode?.identifier == "ru"
    }

    /// Страница оплаты картами РФ и СБП. Замените на боевой адрес сайта.
    static let russianPaymentURL = URL(string: "https://nofap.app/pay")!
}
