//
//  AvatarScreen.swift
//  NoFap
//
//  Аватар — античный воин-стоик, который растёт из младенца в пелёнках до
//  закалённого спартанца. Пока готова первая стадия; ранги и следующие
//  стадии подставятся по мере появления картинок.
//

import SwiftUI

/// Стадии аватара. Картинка есть пока только у первой.
enum WarriorStage: Int, CaseIterable {
    case infant = 1

    var title: LocalizedStringResource {
        switch self {
        case .infant: "Младенец"
        }
    }

    var imageName: String {
        switch self {
        case .infant: "AvatarStage1"
        }
    }

    /// Римская цифра ранга — в античном духе.
    var rank: String {
        switch self {
        case .infant: "I"
        }
    }
}

struct AvatarScreen: View {

    @Environment(StreakManager.self) private var streak

    private var stage: WarriorStage { .infant }

    /// Доля пути к личной цели — та же мера, что у прогресса на главном.
    private var fraction: Double {
        let goal = max(streak.personalGoalDays, 1)
        return min(Double(streak.currentStreak) / Double(goal), 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Eyebrow(text: "ранг \(stage.rank)", color: Palette.gold)
                    Text(stage.title)
                        .font(Face.display(28, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                }
                .padding(.top, 8)

                Image(stage.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .padding(.vertical, 8)
                    .background(alignment: .bottom) {
                        // Тёплое пятно света под фигуркой — она стоит «на
                        // сцене». Размытый эллипс, а не градиент в рамке:
                        // у того проступали углы картинки.
                        Ellipse()
                            .fill(Palette.gold.opacity(0.22))
                            .frame(width: 220, height: 50)
                            .blur(radius: 24)
                            .offset(y: -6)
                    }
                    .accessibilityLabel(Text("Аватар: \(stage.title)"))

                progressCard

                Text("Каждый чистый день приближает тебя к цели. Взятая цель — новый ранг и новая форма воина.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle("Аватар")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("До цели")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.ash)
                Spacer()
                Text("\(streak.currentStreak) из \(max(streak.personalGoalDays, 1)) дней")
                    .font(Face.display(15, .semibold))
                    .foregroundStyle(.goldFill)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.vein)
                    Capsule().fill(.goldFill)
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
            .animation(.easeInOut(duration: 0.6), value: fraction)
        }
        .padding(16)
        .cardSurface()
    }
}
