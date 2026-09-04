//
//  PartnerBadge.swift
//  NoFap
//
//  Напарник в углу карточки прогресса: та же картинка целиком, что и на
//  главном камне, просто в уменьшенном масштабе — не кроп текстуры,
//  а полный рисунок с числом внутри валуна, как на большой карточке.
//

import SwiftUI

struct PartnerBadge: View {

    @Environment(PartnerManager.self) private var partner

    let width: CGFloat

    /// На карточке прогресса число нужно внутри валуна, а на экране
    /// напарника число уже показано отдельно крупно — там оно не нужно.
    var showsCount: Bool = true

    /// Те же доли, что и у основной цифры в ProgressTabView — валун
    /// находится в одном и том же месте на любом масштабе одной картинки.
    private enum Boulder {
        static let photoRatio: CGFloat = 515.0 / 493.0
        static let centerX: CGFloat = 0.70
        static let centerYRatio: CGFloat = 0.354   // доля от высоты, как в ProgressTabView
        static let numberScale: CGFloat = 0.14
    }

    private var height: CGFloat { width * Boulder.photoRatio }

    var body: some View {
        if let profile = partner.partner {
            paired(profile)
        } else {
            empty
        }
    }

    // MARK: - Есть напарник

    private func paired(_ profile: PartnerProfile) -> some View {
        ZStack {
            Image("SisyphusPhoto")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .clipShape(.rect(cornerRadius: width * 0.09))

            if showsCount {
                // Только сам стрик — подпись цели на таком масштабе всё равно
                // не читалась, только шумела рядом с числом.
                Text("\(profile.currentStreak)")
                    .font(Face.display(width * Boulder.numberScale, .semibold))
                    .foregroundStyle(profile.isStale ? AnyShapeStyle(Palette.ash) : AnyShapeStyle(.goldFill))
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                    .contentTransition(.numericText())
                    .position(x: width * Boulder.centerX, y: height * Boulder.centerYRatio)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Напарника нет

    /// Тихая заглушка того же формата, что и картинка: приглашает, но не
    /// спорит со стриком — без золота и без свечения.
    private var empty: some View {
        RoundedRectangle(cornerRadius: width * 0.09)
            .strokeBorder(Palette.ash.opacity(0.5),
                          style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: width * 0.24, weight: .light))
                    if showsCount {
                        Text("напарник")
                            .font(.system(size: width * 0.11))
                    }
                }
                .foregroundStyle(Palette.ash)
            }
    }
}
