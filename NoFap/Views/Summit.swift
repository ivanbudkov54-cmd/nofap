//
//  Summit.swift
//  NoFap
//
//  Вершина с восходящим светом — фон карточки стрика. Нарисована вектором,
//  а не картинкой: масштабируется под любой экран, весит ноль и берёт
//  цвета из палитры, поэтому не расходится с остальным интерфейсом.
//

import SwiftUI

struct Summit: View {

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height

            ZStack {
                sky
                halo(w: w, h: h)
                beam(w: w, h: h)

                // Дальняя гряда — светлее и мягче, создаёт глубину.
                ridge(w: w, h: h, peakX: 0.28, peakY: 0.80, spread: 0.62)
                    .fill(Palette.vein.opacity(0.55))
                    .blur(radius: 1.5)

                ridge(w: w, h: h, peakX: 0.76, peakY: 0.84, spread: 0.58)
                    .fill(Palette.vein.opacity(0.40))
                    .blur(radius: 1.5)

                // Главный пик — самый тёмный, чтобы фигура на нём читалась.
                ridge(w: w, h: h, peakX: 0.5, peakY: 0.70, spread: 0.54)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x1A1A20), Color(hex: 0x0B0B0E)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                climber(w: w, h: h)
            }
        }
        .clipped()
    }

    private var sky: some View {
        LinearGradient(
            colors: [Color(hex: 0x121219), Color(hex: 0x0A0A0D)],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Свечение за вершиной — источник света всей сцены.
    private func halo(w: CGFloat, h: CGFloat) -> some View {
        RadialGradient(
            colors: [Palette.goldLight.opacity(0.55), Palette.gold.opacity(0.16), .clear],
            center: .init(x: 0.5, y: 0.70),
            startRadius: 2,
            endRadius: w * 0.55
        )
        .blur(radius: 10)
    }

    /// Вертикальный столб света из вершины вверх.
    private func beam(w: CGFloat, h: CGFloat) -> some View {
        LinearGradient(
            colors: [.clear, Palette.goldLight.opacity(0.5), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(width: 2.5, height: h * 0.50)
        .blur(radius: 3)
        .position(x: w * 0.5, y: h * 0.40)
    }

    /// Профиль склона в долях от вершины: смещение по X и спуск по Y.
    /// Асимметричный и с уступами — симметричный треугольник читается как схема.
    private static let profile: [(dx: CGFloat, dy: CGFloat)] = [
        (-1.00, 1.00), (-0.66, 0.46), (-0.48, 0.54), (-0.24, 0.17),
        (-0.09, 0.06), (0, 0), (0.13, 0.11), (0.31, 0.05),
        (0.50, 0.44), (0.72, 0.35), (1.00, 1.00)
    ]

    private func ridge(w: CGFloat, h: CGFloat, peakX: CGFloat, peakY: CGFloat, spread: CGFloat) -> Path {
        Path { p in
            let apexX = w * peakX
            let apexY = h * peakY
            let drop = h - apexY

            for (i, point) in Self.profile.enumerated() {
                let pt = CGPoint(x: apexX + point.dx * spread * w, y: apexY + point.dy * drop)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }

    /// Фигура на вершине — единственная тёплая точка на тёмном силуэте.
    private func climber(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 1) {
            Circle().frame(width: 4, height: 4)
            Capsule().frame(width: 4, height: 11)
        }
        .foregroundStyle(Color(hex: 0x050506))
        .shadow(color: Palette.goldLight.opacity(0.9), radius: 5)
        .position(x: w * 0.5, y: h * 0.70 - 9)
    }
}
