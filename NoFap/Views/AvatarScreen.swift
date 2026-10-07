//
//  AvatarScreen.swift
//  NoFap
//
//  Вкладка «Аватар»: спартанец текущего ранга, а за ним справа в дымке —
//  следующий, к которому идёшь. Ниже полоса опыта до него. Торжество при
//  открытии нового ранга — SpartanLevelUpView.
//  Очки и пороги — AvatarProgressManager.
//

import SwiftUI

struct AvatarScreen: View {

    @Environment(AvatarProgressManager.self) private var progress

    @State private var detailRank: SpartanRank?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Заголовок — частью страницы, а не панели: при прокрутке
                // он уезжает вместе с контентом, а не висит поверх него.
                Text("Аватар")
                    .font(Face.display(28, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                scene
                xpCard
                rewardsHint
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // Без заголовка в панели (iOS 17 не умеет убирать его иначе) —
        // остаётся только кнопка «назад».
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detailRank) { rank in
            SpartanDetailSheet(rank: rank)
        }
    }

    // MARK: - Сцена

    private var scene: some View {
        let rank = progress.currentRank

        return VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                // Следующий ранг — за спиной, справа и выше, меньше и в
                // серой дымке: видно, к кому идёшь.
                if let next = progress.nextRank {
                    Button { detailRank = next } label: {
                        ZStack {
                            // Мягкий свет со стороны будущего ранга.
                            Circle()
                                .fill(Palette.gold.opacity(0.22))
                                .frame(width: 190, height: 190)
                                .blur(radius: 50)
                            SpartanFigure(rank: next, size: 185)
                                .saturation(0.25)
                                .brightness(-0.05)
                                .opacity(0.6)
                        }
                    }
                    .buttonStyle(.plain)
                    // Главный стоит по центру; следующий — справа за его
                    // плечом, у самого края экрана.
                    .offset(x: 105, y: -45)
                    .accessibilityLabel(Text("Следующий ранг: \(Text(next.title))"))
                }

                SpartanFigure(rank: rank, size: 240, floating: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            Text("Ранг \(rank.rawValue) из \(SpartanRank.allCases.count) • \(Text(rank.title))")
                .font(Face.display(17, .semibold))
                .foregroundStyle(.goldFill)
                .multilineTextAlignment(.center)

            Text(rank.summary)
                .font(Face.quote(16))
                .foregroundStyle(Palette.marble.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Опыт

    private var xpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "опыт", color: Palette.gold)
                Spacer()
                Text(progress.nextRank == nil
                     ? "\(progress.totalXP) XP"
                     : "\(progress.totalXP) / \(progress.nextLevelTargetXP) XP")
                    .font(Face.display(15, .semibold))
                    .foregroundStyle(.goldFill)
                    .contentTransition(.numericText())
            }

            XPBar(value: progress.levelProgress)

            Text(progress.nextRank == nil
                 ? "Высший ранг взят. Путь воина продолжается."
                 : "До следующего ранга осталось: \(progress.xpRemainingToNextLevel) XP")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
        .padding(16)
        .cardSurface()
        .animation(.easeInOut(duration: 0.6), value: progress.totalXP)
    }

    private var rewardsHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "как получать опыт", color: Palette.marble)
            hintRow("flag.fill", "Челлендж", "+100 XP, сложный или социальный — +150")
            hintRow("flame.fill", "День стрика", "+50 XP, бонусы на 7, 21, 45 и 90 день")
            hintRow("book.fill", "Статья", "+20 XP, научная — +30, один раз за статью")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface()
    }

    private func hintRow(_ icon: String, _ title: LocalizedStringResource, _ detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Palette.gold)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.marbleHigh)
                Text(detail).font(.system(size: 13)).foregroundStyle(Palette.ash)
            }
        }
    }
}

// MARK: - Фигура

/// Картинка ранга. Пока нарисованы не все — до появления арта показываем
/// ближайший нарисованный ранг ниже, а если нет и его, силуэт.
struct SpartanFigure: View {
    let rank: SpartanRank
    let size: CGFloat
    var floating = false
    var silhouette = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    private var artworkRank: SpartanRank? {
        SpartanRank.allCases.filter { $0 <= rank && $0.hasArtwork }.last
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Тень на «полу» — сжимается, когда фигура приподнимается.
            Ellipse()
                .fill(Palette.gold.opacity(silhouette ? 0 : 0.22))
                .frame(width: size * 0.7, height: size * 0.14)
                .blur(radius: size * 0.08)
                .scaleEffect(lifted ? 0.85 : 1)

            figure
                .frame(width: size, height: size)
                .offset(y: lifted ? -size * 0.04 : 0)
        }
        .frame(width: size, height: size * 1.04)
        .onAppear {
            guard floating, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { lifted = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(rank.title))
    }

    @ViewBuilder
    private var figure: some View {
        if let art = artworkRank {
            // Силуэт — та же картинка в режиме шаблона: остаётся только
            // контур фигуры, без деталей.
            Image(art.assetName)
                .renderingMode(silhouette ? .template : .original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .foregroundStyle(Color(hex: 0x1C1C22))
        } else {
            Image(systemName: "figure.stand")
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
                .foregroundStyle(silhouette ? Color(hex: 0x1C1C22) : Palette.marble)
        }
    }
}

// MARK: - Полоса опыта

private struct XPBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0x24242B))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.goldLight, Palette.gold],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(width, value > 0 ? 10 : 0))
                    .shadow(color: Palette.gold.opacity(0.45), radius: 6)
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel(Text("Прогресс ранга"))
        .accessibilityValue(Text("\(Int((value * 100).rounded())) процентов"))
    }
}

// MARK: - Подробно о ранге

private struct SpartanDetailSheet: View {
    let rank: SpartanRank

    var body: some View {
        VStack(spacing: 16) {
            SpartanFigure(rank: rank, size: 260, floating: true)
                .padding(.top, 28)
            Eyebrow(text: "ранг \(rank.rawValue)", color: Palette.gold)
            Text(rank.title)
                .font(Face.display(24, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .multilineTextAlignment(.center)
            Text(rank.summary)
                .font(Face.quote(17))
                .foregroundStyle(Palette.marble)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Spacer()
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.obsidian)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Новый ранг

struct SpartanLevelUpView: View {
    let rank: SpartanRank
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()

            // Свечение за фигурой.
            Circle()
                .fill(Palette.gold.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .scaleEffect(appeared ? 1 : 0.4)

            if !reduceMotion { Embers(active: appeared) }

            VStack(spacing: 18) {
                Spacer()
                Text("Новый спартанский ранг разблокирован!")
                    .textCase(.uppercase)
                    .font(Face.display(15, .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.goldFill)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                SpartanFigure(rank: rank, size: 280, floating: true)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Ранг \(rank.rawValue) из \(SpartanRank.allCases.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ash)
                    Text(rank.title)
                        .font(Face.display(28, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                        .multilineTextAlignment(.center)
                    Text(rank.summary)
                        .font(Face.quote(17))
                        .foregroundStyle(Palette.marble)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                Button("Продолжить путь воина", action: onContinue)
                    .buttonStyle(GoldButton())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

/// Золотые искры, поднимающиеся вверх. Положения фиксированы от индекса —
/// без случайности при каждой перерисовке.
private struct Embers: View {
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<24, id: \.self) { i in
                let x = CGFloat((i * 37) % 100) / 100 * geo.size.width
                let size = CGFloat(3 + (i % 4))
                Circle()
                    .fill(Palette.goldLight)
                    .frame(width: size, height: size)
                    .shadow(color: Palette.gold, radius: 4)
                    .position(x: x, y: active ? -20 : geo.size.height * (0.6 + CGFloat(i % 5) * 0.08))
                    .opacity(active ? 0 : 0.9)
                    .animation(.easeOut(duration: 2.2 + Double(i % 6) * 0.35)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i % 8) * 0.25),
                               value: active)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
