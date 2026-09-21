//
//  Plurals.swift
//  NoFap
//
//  Склонение «день/дня/дней» отдано каталогу локализации: у него встроены
//  правила множественного числа для каждого языка — три русские формы,
//  две английские. Ручная арифметика по остатку от деления знала только
//  русский и умерла бы на первом же новом языке.
//
//  Каталог требует, чтобы каждая форма содержала само число. Но на экране
//  слово часто стоит отдельно от большой цифры — поэтому форматируем с
//  числом, а потом отрезаем его: во всех вариантах число идёт первым.
//

import Foundation

extension Int {
    /// «1 день» / «2 дня» / «5 дней» — число вместе со словом.
    var daysCount: String {
        String(localized: "\(self) дней")
    }

    /// «день» / «дня» / «дней» — слово под большим числом, без самого числа.
    var dayWord: String {
        withoutNumber(daysCount)
    }

    /// «день подряд» / «дня подряд» / «дней подряд» — тоже без числа.
    var dayWordInARow: String {
        withoutNumber(String(localized: "\(self) дней подряд"))
    }

    /// «день — твой первый рубеж» и т.д. — подпись под числом на треке.
    var daysMilestoneWord: String {
        withoutNumber(String(localized: "\(self) дней — твой первый рубеж"))
    }

    private func withoutNumber(_ formatted: String) -> String {
        let prefix = "\(self) "
        return formatted.hasPrefix(prefix) ? String(formatted.dropFirst(prefix.count)) : formatted
    }
}
