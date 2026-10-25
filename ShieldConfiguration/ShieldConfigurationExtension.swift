//
//  ShieldConfigurationExtension.swift
//  ShieldConfiguration
//
//  Экран, который iOS показывает вместо заблокированного приложения или
//  сайта. Рисует его система — расширение только отдаёт тексты, цвета и
//  иконку. Своих view здесь нет и быть не может.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield()
    }

    private func shield() -> ShieldConfiguration {
        let days = ShieldShared.streakDays
        let title = days > 0 ? "Стоп. \(daysText(days)) без срыва." : "Стоп. Ты сам это закрыл."

        // Цитата из «Договора с собой» бьёт сильнее общих слов, но она
        // длинная — у щита на подзаголовок места немного.
        let subtitle = ShieldShared.quote
            ?? "Тяга — это волна. Через 15–20 минут она спадёт. Не открывай — переживи её."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 10 / 255, green: 10 / 255, blue: 13 / 255, alpha: 1),
            icon: UIImage(named: "ShieldIcon"),
            title: .init(text: title, color: UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)),
            subtitle: .init(text: subtitle, color: UIColor(red: 0.62, green: 0.60, blue: 0.56, alpha: 1)),
            primaryButtonLabel: .init(text: "SOS", color: UIColor(red: 0.08, green: 0.07, blue: 0.05, alpha: 1)),
            primaryButtonBackgroundColor: UIColor(red: 0.85, green: 0.70, blue: 0.40, alpha: 1),
            secondaryButtonLabel: .init(text: "Я справлюсь", color: UIColor(red: 0.85, green: 0.70, blue: 0.40, alpha: 1))
        )
    }

    private func daysText(_ days: Int) -> String {
        let mod10 = days % 10
        let mod100 = days % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "день"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = "дня"
        } else {
            word = "дней"
        }
        return "\(days) \(word)"
    }
}
