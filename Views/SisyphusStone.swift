//
//  SisyphusStone.swift
//  NoFap
//
//  Камень Сизифа как рамка для статистики месяца. Иллюстрация — template-ассет,
//  поэтому красится палитрой. Число рисуется кодом поверх картинки, ровно в
//  геометрическом центре клубка — не в естественном просвете штриховки, у
//  которого центр был смещён и не совпадал с центром самого клубка.
//

import SwiftUI

struct SisyphusStone: View {

    let clean: Int
    let total: Int

    /// Аспект исходного рисунка и геометрия клубка — доли от ширины/высоты
    /// картинки, не пиксели, чтобы вид не зависел от размера показа.
    /// Картинка уже дополнена прозрачным полем справа, чтобы центр клубка
    /// совпадал с горизонтальным центром кадра.
    private enum Art {
        static let aspect: CGFloat = 898.0 / 817.0
        static let ballX: CGFloat = 0.5
        static let ballY: CGFloat = 0.309
        static let ballRadius: CGFloat = 0.275
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w * Art.ballX, y: h * Art.ballY)
            let holeRadius = w * Art.ballRadius * 0.42

            ZStack {
                Image("SisyphusStone")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.goldFill)
                    .frame(width: w, height: h)

                // Чистый вырез под статистику — ровно в центре клубка.
                Circle()
                    .fill(Palette.obsidian)
                    .frame(width: holeRadius * 2, height: holeRadius * 2)
                    .position(center)

                VStack(spacing: 1) {
                    Text("\(clean)")
                        .font(Face.display(w * 0.10, .semibold))
                        .foregroundStyle(.goldFill)
                        .contentTransition(.numericText())

                    Text("из \(total) дней")
                        .font(Face.display(w * 0.024))
                        .foregroundStyle(Palette.ash)
                }
                .position(center)
            }
            .frame(width: w, height: h, alignment: .center)
        }
        .aspectRatio(Art.aspect, contentMode: .fit)
    }
}
