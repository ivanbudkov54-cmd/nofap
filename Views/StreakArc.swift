//
//  StreakArc.swift
//  NoFap
//
//  Подпись экрана: разомкнутая дуга из 30 засечек — месяц. Каждая засечка
//  один день, заработанные горят золотом. Внутри — счётчик, набранный
//  мрамором и подсвеченный золотом изнутри, как сердце скульптуры.
//

import SwiftUI

struct StreakArc: View {

    let streak: Int

    private let ticks = 30
    private let sweep: Double = 260

    var body: some View {
        GeometryReader { geo in
            let radius = geo.size.width / 2 - 10

            ZStack {
                glow
                marks(radius: radius)
                counter
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1.18, contentMode: .fit)
    }

    /// Золото, просвечивающее сквозь камень.
    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Palette.gold.opacity(0.30), Palette.gold.opacity(0.06), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 130
                )
            )
            .blur(radius: 22)
    }

    private func marks(radius: CGFloat) -> some View {
        ForEach(0..<ticks, id: \.self) { i in
            let earned = i < min(streak, ticks)

            Capsule()
                .fill(earned ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein))
                .frame(width: 1.5, height: earned ? 14 : 9)
                .shadow(color: earned ? Palette.gold.opacity(0.6) : .clear, radius: 4)
                .offset(y: -radius)
                .rotationEffect(.degrees(angle(for: i)))
        }
    }

    private var counter: some View {
        VStack(spacing: 2) {
            Text("\(streak)")
                .font(Face.display(88, .medium))
                .foregroundStyle(.marbleFill)
                .shadow(color: Palette.gold.opacity(0.35), radius: 18)
                .contentTransition(.numericText())

            Eyebrow(text: dayWord(streak))
        }
    }

    private func angle(for index: Int) -> Double {
        -sweep / 2 + sweep * Double(index) / Double(ticks - 1)
    }

    private func dayWord(_ n: Int) -> String {
        let mod100 = n % 100, mod10 = n % 10
        if (11...14).contains(mod100) { return "дней подряд" }
        return switch mod10 {
        case 1: "день подряд"
        case 2...4: "дня подряд"
        default: "дней подряд"
        }
    }
}
