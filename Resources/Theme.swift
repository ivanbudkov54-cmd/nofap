//
//  Theme.swift
//  NoFap
//
//  Направление «золото в мраморе»: белый фон, тёмные полутона текста,
//  золото только там, где есть достижение. Золото — не декор, а награда:
//  им светится только то, что пользователь заработал.
//

import SwiftUI
import CoreText

enum Palette {
    static let obsidian   = Color(hex: 0xFFFFFF)  // фон
    static let basalt     = Color(hex: 0xF4F4F7)  // карточки
    static let vein       = Color(hex: 0xDDDFE5)  // прожилки, границы
    static let marbleHigh = Color(hex: 0x1C1C22)  // основной текст
    static let marble     = Color(hex: 0x3D3D45)  // текст
    static let ash        = Color(hex: 0x6B6B78)  // вторичный текст
    static let gold       = Color(hex: 0xE5B94E)
    static let goldLight  = Color(hex: 0xF7D98C)
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
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.ash

    var body: some View {
        Text(text.uppercased())
            .font(Face.display(11, .semibold))
            .tracking(2.4)
            .foregroundStyle(color)
    }
}

/// Мраморная заливка: сверху блик, снизу тень — как на полированном камне.
extension ShapeStyle where Self == LinearGradient {
    static var marbleFill: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x121218), Palette.marbleHigh, Palette.marble],
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
