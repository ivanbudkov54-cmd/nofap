//
//  Theme.swift
//  NoFap
//
//  Направление «золото в мраморе»: почти чёрный фон, мраморные полутона,
//  золото только там, где есть достижение. Золото — не декор, а награда:
//  им светится только то, что пользователь заработал.
//

import SwiftUI
import CoreText
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Как в системе"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// nil означает «следовать системе».
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    private static let key = "app_theme"

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.key) }
    }

    init() {
        // По умолчанию тёмная: «золото в мраморе» рисовалось под неё, а
        // светлую человек выбирает сам в настройках.
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppTheme.dark.rawValue
        theme = AppTheme(rawValue: raw) ?? .dark
    }
}

enum Palette {
    /// Фон, карточки, границы и текст меняются вместе со схемой,
    /// золото остаётся наградой в обеих темах.
    static let obsidian   = Color(uiColor: dynamic(dark: 0x0A0A0D, light: 0xFFFFFF))
    static let basalt     = Color(uiColor: dynamic(dark: 0x141418, light: 0xF4F4F7))
    static let vein       = Color(uiColor: dynamic(dark: 0x2C2C34, light: 0xDDDFE5))
    static let marbleHigh = Color(uiColor: dynamic(dark: 0xE4E7EF, light: 0x1C1C22))
    static let marble     = Color(uiColor: dynamic(dark: 0xB8BECD, light: 0x3D3D45))
    static let ash        = Color(uiColor: dynamic(dark: 0x7A7A87, light: 0x6B6B78))
    static let tabBar     = dynamic(dark: 0x0A0A0D, light: 0xFFFFFF)

    /// UIKit вызывает этот блок с фонового потока отрисовки.
    /// При изоляции MainActor по умолчанию такой вызов обрывает приложение.
    nonisolated private static func dynamic(dark: UInt32, light: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex)
        }
    }
    // Тон и насыщенность взяты из свечения на фото «Твой стрик» (#F5BE4E) —
    // раньше goldLight терял насыщенность и уходил в бледно-жёлтый, поэтому
    // общий золотой на экране читался холоднее и менее оранжевым, чем на фото.
    static let gold       = Color(hex: 0xF0BC4F)
    static let goldLight  = Color(hex: 0xF7CF7C)
    // Приглушённый гранатовый, а не системный Color.red — тот же смысл
    // «тревога», но без ядовитой ноты чистого iOS-red на фоне тёплого золота.
    static let garnet      = Color(hex: 0xE0524A)
    static let garnetLight = Color(hex: 0xE87A70)
}

enum Face {
    /// Unbounded ведёт весь интерфейс — от заголовков до подписей в таб-баре.
    /// Брутальный, угловатый, с полноценной кириллицей. Системный шрифт
    /// остаётся только там, где его задаёт сама iOS.
    static func display(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func quote(_ size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Italic", size: size)
    }

    enum Weight {
        case regular, medium, semibold

        var postScriptName: String {
            switch self {
            case .regular:  "Unbounded-Regular"
            case .medium:   "Unbounded-Medium"
            case .semibold: "Unbounded-Bold"
            }
        }
    }

    /// Регистрируем шрифты из бандла вручную — не зависим от ключа UIAppFonts
    /// в генерируемом Info.plist.
    static func register() {
        for name in ["PlayfairDisplay-Italic",
                     "Unbounded-Regular", "Unbounded-Medium", "Unbounded-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Надпись-надзаголовок: прописные, разрежённые, как на музейной табличке.
///
/// Два инициализатора по образцу `Text(_:)` / `Text(verbatim:)`: литерал
/// уходит в каталог локализации как ключ, а уже переведённая строка
/// (например, склонённое слово) выводится как есть.
struct Eyebrow: View {
    private let content: Text
    private let color: Color

    init(text: LocalizedStringResource, color: Color = Palette.ash) {
        content = Text(text)
        self.color = color
    }

    init(verbatim: String, color: Color = Palette.ash) {
        content = Text(verbatim: verbatim)
        self.color = color
    }

    var body: some View {
        // `.textCase` вместо `.uppercased()`: прописные считаются по правилам
        // текущего языка, а не по правилам строки в коде.
        content
            .textCase(.uppercase)
            .font(Face.display(11, .semibold))
            .tracking(2.4)
            .foregroundStyle(color)
    }
}

/// Мраморная заливка: сверху блик, снизу тень — как на полированном камне.
extension ShapeStyle where Self == LinearGradient {
    /// Блик по камню, а не затухание. Раньше градиент доходил до `ash` —
    /// цвета второстепенного текста, и на заголовке в три строки последняя
    /// строка теряла акцент, будто она менее важна. Теперь основная масса
    /// букв держит полную яркость, и лишь у самого низа появляется намёк
    /// на полутон.
    static var marbleFill: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Palette.marbleHigh, location: 0.0),
                .init(color: Palette.marbleHigh, location: 0.75),
                .init(color: Palette.marble, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var goldFill: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight, Palette.gold],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
