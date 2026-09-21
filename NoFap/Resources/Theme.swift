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

enum Palette {
    static let obsidian   = Color(hex: 0x0A0A0D)  // фон
    static let basalt     = Color(hex: 0x141418)  // карточки
    static let vein       = Color(hex: 0x2C2C34)  // прожилки, границы
    static let marbleHigh = Color(hex: 0xE4E7EF)  // блик мрамора
    static let marble     = Color(hex: 0xB8BECD)  // основной текст
    static let ash        = Color(hex: 0x7A7A87)  // вторичный текст
    // Тон и насыщенность взяты из свечения на фото «Твой стрик» (#F5BE4E) —
    // раньше goldLight терял насыщенность и уходил в бледно-жёлтый, поэтому
    // общий золотой на экране читался холоднее и менее оранжевым, чем на фото.
    static let gold       = Color(hex: 0xF0BC4F)
    static let goldLight  = Color(hex: 0xF7CF7C)
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
