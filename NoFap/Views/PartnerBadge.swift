//
//  PartnerBadge.swift
//  NoFap
//
//  Напарник в углу карточки прогресса: тот же валун, только маленький.
//  Переиспользуем ассет SisyphusPhoto, а не заводим второй — иначе они
//  разойдутся при следующей правке картинки.
//

import SwiftUI

struct PartnerBadge: View {

    @Environment(PartnerManager.self) private var partner

    let diameter: CGFloat

    /// На карточке прогресса число нужно, а на экране напарника оно уже
    /// нарисовано крупно рядом — иначе двоится.
    var showsCount: Bool = true

    /// Доли, по которым валун найден на фото: границы валуна в исходнике
    /// 493×515 — x 197…468, y 68…297. Отсюда и центр, и ширина.
    private enum Boulder {
        static let centerX: CGFloat = 0.674
        static let centerY: CGFloat = 0.354
        static let widthShare: CGFloat = 0.55
        static let photoRatio: CGFloat = 515.0 / 493.0
    }

    var body: some View {
        if let profile = partner.partner {
            paired(profile)
        } else {
            empty
        }
    }

    // MARK: - Есть напарник

    private func paired(_ profile: PartnerProfile) -> some View {
        VStack(spacing: 5) {
            ZStack {
                boulderCrop
                    .clipShape(.circle)

                Circle()
                    .strokeBorder(ringColor(for: profile), lineWidth: 1.8)
            }
            .frame(width: diameter, height: diameter)

            if showsCount {
                Text("\(profile.currentStreak)")
                    .font(Face.display(diameter * 0.30, .semibold))
                    .foregroundStyle(profile.isStale ? AnyShapeStyle(Palette.ash) : AnyShapeStyle(.goldFill))
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                    .contentTransition(.numericText())
            }
        }
    }

    /// Кроп по валуну: увеличиваем фото так, чтобы валун занял весь кружок,
    /// и сдвигаем его центр в центр кадра.
    private var boulderCrop: some View {
        let side = diameter / Boulder.widthShare
        let height = side * Boulder.photoRatio

        return Image("SisyphusPhoto")
            .resizable()
            .scaledToFill()
            .frame(width: side, height: height)
            .offset(x: -(Boulder.centerX - 0.5) * side,
                    y: -(Boulder.centerY - 0.5) * height)
            .frame(width: diameter, height: diameter)
    }

    /// Золото — награда, а не украшение: кольцо загорается, только если
    /// напарник отметился сегодня.
    private func ringColor(for profile: PartnerProfile) -> Color {
        if profile.isStale { return Palette.ash.opacity(0.5) }
        return profile.isHoldingToday ? Palette.gold : Palette.vein
    }

    // MARK: - Напарника нет

    /// Тихая заглушка: она должна приглашать, но не спорить со стриком,
    /// поэтому без золота и без свечения.
    private var empty: some View {
        VStack(spacing: 5) {
            Circle()
                .strokeBorder(Palette.ash.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .frame(width: diameter, height: diameter)
                .overlay {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: diameter * 0.32, weight: .light))
                        .foregroundStyle(Palette.ash)
                }

            if showsCount {
                Text("напарник")
                    .font(.system(size: diameter * 0.15))
                    .foregroundStyle(Palette.ash)
            }
        }
    }
}
