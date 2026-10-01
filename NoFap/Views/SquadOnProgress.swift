//
//  SquadOnProgress.swift
//  NoFap
//
//  Сквад на карточке «Свобода в этом месяце»: до трёх плашек на самой
//  картинке. Напарник рисуется отдельно — прежним большим значком в левом
//  нижнем углу (PartnerBadge), плашки сквада стоят вокруг него.
//

import SwiftUI

/// Кусок той же картинки с Сизифом — только валун и фигура, с числом дней
/// на камне. Вырезается из целого кадра, а не рисуется отдельно, чтобы
/// плашка выглядела частью сцены.
struct SisyphusToken: View {

    let streak: Int
    var stale = false
    let width: CGFloat

    /// Окно кадрирования в долях целого кадра — вымерено по самой картинке:
    /// валун с фигурой и немного горы под ними.
    private enum Crop {
        static let x: CGFloat = 0.41, y: CGFloat = 0.10
        static let width: CGFloat = 0.54, height: CGFloat = 0.85
        static let photoRatio: CGFloat = 515.0 / 493.0
        static let boulder = CGPoint(x: 0.70, y: 0.354)
    }

    private var height: CGFloat { Self.height(forWidth: width) }

    static func height(forWidth width: CGFloat) -> CGFloat {
        Crop.height * (width / Crop.width) * Crop.photoRatio
    }
    private var corner: CGFloat { width * 0.16 }

    var body: some View {
        let full = width / Crop.width
        let fullHeight = full * Crop.photoRatio

        return ZStack(alignment: .topLeading) {
            Image("SisyphusPhoto")
                .resizable()
                .scaledToFit()
                .frame(width: full, height: fullHeight)
                .offset(x: -Crop.x * full, y: -Crop.y * fullHeight)

            Text("\(streak)")
                .font(Face.display(width * 0.26, .semibold))
                .foregroundStyle(stale ? AnyShapeStyle(Palette.ash) : AnyShapeStyle(.goldFill))
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                .contentTransition(.numericText())
                .position(x: (Crop.boulder.x - Crop.x) / Crop.width * width,
                          y: (Crop.boulder.y - Crop.y) / Crop.height * height)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: corner))
    }
}

/// Трое из сквада на картинке. Центры плашек — в долях карточки, по
/// согласованному наброску: одна справа от напарника внизу, две столбиком
/// выше у левого края — над его углом, не задевая его.
struct SquadOnImage: View {

    @Environment(PartnerManager.self) private var partner
    @Environment(SquadManager.self) private var squad

    let onTap: () -> Void

    private static let spots = [CGPoint(x: 0.457, y: 0.859),
                                CGPoint(x: 0.110, y: 0.545),
                                CGPoint(x: 0.110, y: 0.262)]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.192
            let mates = squadMates
            // Нижняя плашка стоит низом вровень с напарником — его значок
            // прижат к нижнему краю карточки.
            let bottomY = geo.size.height - SisyphusToken.height(forWidth: width) / 2

            ZStack {
                // Только те, кто уже в скваде: пустые места на картинке не
                // рисуются — позвать людей можно на экране сквада.
                ForEach(Array(mates.prefix(Self.spots.count).enumerated()), id: \.element.id) { index, member in
                    SisyphusToken(streak: member.currentStreak,
                                  stale: member.isStale,
                                  width: width)
                        .position(x: Self.spots[index].x * geo.size.width,
                                  y: index == 0 ? bottomY : Self.spots[index].y * geo.size.height)
                        .onTapGesture(perform: onTap)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(squadMates.isEmpty)
    }

    /// Напарник может состоять и в скваде — на картинке он один раз, в
    /// своём углу.
    private var squadMates: [PartnerProfile] {
        squad.members.filter { $0.id != partner.partner?.id }
    }

    private var accessibilitySummary: String {
        let names = squadMates.map { "\($0.nickname): \($0.currentStreak)" }
        return names.isEmpty ? String(localized: "Сквад: пока никого")
                             : String(localized: "Сквад: \(names.joined(separator: ", "))")
    }
}
