//
//  Haptics.swift
//  NoFap
//
//  Одна таблица вибраций на всё приложение — чтобы одинаковые по смыслу
//  действия отзывались одинаково:
//
//  - selection — переключение вкладок, сегментов, чипов, вариантов ответа;
//  - light     — второстепенные кнопки, отмена, открытие экранов;
//  - medium    — главное действие экрана (золотая кнопка);
//  - heavy     — SOS: самый сильный удар, рука сразу чувствует, что нажато;
//  - soft      — «Срыв»: заметно, но мягко, без наказания;
//  - success   — заработанное: отметка «Держусь», челлендж, новый ранг;
//  - warning   — необратимое: удаление.
//

import UIKit

enum Haptics {

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light()  { impact(.light) }
    static func medium() { impact(.medium) }
    static func heavy()  { impact(.heavy) }
    static func soft()   { impact(.soft, intensity: 0.8) }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1) {
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }
}
