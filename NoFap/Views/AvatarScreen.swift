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
                    .frame(maxWidth: .infinity, alignment: .center)
                    // На уровень кнопки «назад» — по центру она не мешает.
                    .padding(.top, -44)
                    .accessibilityAddTraits(.isHeader)

                scene
                xpCard
                hall
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
            SpartanDetailSheet(rank: rank, progress: progress)
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
                                .fill(Palette.gold.opacity(0.12 + 0.2 * progress.levelProgress))
                                .frame(width: 190, height: 190)
                                .blur(radius: 50)
                            // Чем ближе ранг, тем больше в нём цвета и
                            // света: в начале почти серый, перед
                            // повышением — почти живой.
                            SpartanFigure(rank: next, size: 185)
                                .saturation(0.15 + 0.75 * progress.levelProgress)
                                .brightness(-0.08 + 0.08 * progress.levelProgress)
                                .opacity(0.5 + 0.4 * progress.levelProgress)
                        }
                        // Тихая подпись под ногами: кто это и сколько до него.
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 1) {
                                Text("следующий")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Palette.ash)
                                Text("ещё \(progress.xpRemainingToNextLevel) XP")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.gold.opacity(0.9))
                            }
                            .fixedSize()
                            .offset(y: 22)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.8), value: progress.levelProgress)
                    // Главный стоит по центру; следующий — справа за его
                    // плечом, у самого края экрана.
                    .offset(x: 140, y: -45)
                    .accessibilityLabel(Text("Следующий ранг: \(Text(next.title))"))
                }

                SpartanFigure(rank: rank, size: 240, breathing: true, reactsToTap: true, shining: true)
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

    // MARK: - Зал славы

    private var hall: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "зал славы", color: Palette.marble)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(SpartanRank.allCases) { rank in
                        let open = rank <= progress.currentRank
                        Button { if open { detailRank = rank } } label: {
                            HallCard(rank: rank, unlocked: open, isCurrent: rank == progress.currentRank,
                                     nextProgress: rank == progress.nextRank ? progress.levelProgress : nil)
                        }
                        .buttonStyle(.plain)
                        .disabled(!open)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            // Карусель шире полей экрана — карточки уходят за край, видно,
            // что их можно листать.
            .padding(.horizontal, -20)
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
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
/// Поза фигуры на нажатие: приседает, подпрыгивает, пружинит обратно.
private struct TapPose {
    var squashX: CGFloat = 1
    var squashY: CGFloat = 1
    var lift: CGFloat = 0
}

struct SpartanFigure: View {
    let rank: SpartanRank
    let size: CGFloat
    var floating = false
    var silhouette = false
    /// Едва заметное «дыхание» — фигура живая, но спокойная.
    var breathing = false
    /// Подпрыгивает с отдачей на нажатие.
    var reactsToTap = false
    /// Блик, пробегающий по фигуре раз в несколько секунд.
    var shining = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false
    @State private var inhale = false
    @State private var bounce = 0

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
                .overlay { if shining && !silhouette && !reduceMotion { shine } }
                // Дыхание — масштаб от ступней, чтобы фигура не «плыла».
                .scaleEffect(x: inhale ? 1.015 : 1, y: inhale ? 1.035 : 1, anchor: .bottom)
                .keyframeAnimator(initialValue: TapPose(), trigger: bounce) { content, pose in
                    content
                        .scaleEffect(x: pose.squashX, y: pose.squashY, anchor: .bottom)
                        .offset(y: pose.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.squashY) {
                        SpringKeyframe(0.9, duration: 0.08)
                        SpringKeyframe(1.08, duration: 0.18)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                    KeyframeTrack(\.squashX) {
                        SpringKeyframe(1.08, duration: 0.08)
                        SpringKeyframe(0.95, duration: 0.18)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                    KeyframeTrack(\.lift) {
                        LinearKeyframe(0, duration: 0.08)
                        SpringKeyframe(-size * 0.09, duration: 0.18)
                        SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                    }
                }
                .offset(y: lifted ? -size * 0.04 : 0)
        }
        .frame(width: size, height: size * 1.04)
        // Жест только у главной фигуры: внутри кнопок (зал славы, фоновый
        // воин) он перехватывал бы нажатие.
        .simultaneousGesture(TapGesture().onEnded {
            if !reduceMotion { bounce += 1 }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }, including: reactsToTap ? .all : .subviews)
        .onAppear {
            guard !reduceMotion else { return }
            if floating {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { lifted = true }
            }
            if breathing {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { inhale = true }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(rank.title))
    }

    /// Сила блика растёт с рангом: у малыша — мягкий глянец виниловой
    /// игрушки, у воинов в бронзе — яркий золотой отблеск металла.
    private var shineStrength: Double {
        switch rank {
        case .initiate, .agoge: 0.45
        case .hoplite, .veteran: 0.6
        default: 0.75
        }
    }

    /// Диагональная полоса света, обрезанная по контуру самой картинки —
    /// бежит только по фигуре, не по фону.
    /// Положение полосы считается прямо от часов: пробег 0.8 с, затем пауза
    /// до 4 с. Без состояния — застрять полосе негде.
    private static func shinePhase(at date: Date) -> CGFloat {
        let cycle = 4.0, sweep = 0.8
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        guard t < sweep else { return -0.6 }
        let p = t / sweep
        let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
        return -0.6 + 1.8 * eased
    }

    @ViewBuilder
    private var shine: some View {
        TimelineView(.animation) { context in
        let shinePhase = Self.shinePhase(at: context.date)
        GeometryReader { geo in
            let w = geo.size.width
            // Узкая чёткая полоса — пробегающий блик, а не заливка светом.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(shineStrength), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.1, height: geo.size.height * 1.6)
                .rotationEffect(.degrees(22))
                .frame(width: w, height: geo.size.height)
                .offset(x: shinePhase * w)
                .blendMode(.plusLighter)
        }
        }
        .mask { figure }
        .allowsHitTesting(false)
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

// MARK: - Карточка зала славы

private struct HallCard: View {
    let rank: SpartanRank
    let unlocked: Bool
    let isCurrent: Bool
    /// Только у следующего ранга: доля пути к нему. Его фигуру видно
    /// сквозь серую дымку — понятно, к кому идёшь. Дальние ранги — силуэты.
    var nextProgress: Double? = nil

    private var isNext: Bool { nextProgress != nil }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // Закрытые ранги видны целиком, лишь чуть приглушены, —
                // чтобы хотелось до них дойти. Замок — маленький значок.
                SpartanFigure(rank: rank, size: 120, silhouette: !unlocked && !rank.hasArtwork)
                    .saturation(unlocked ? 1 : 0.8)
                    .opacity(unlocked ? 1 : 0.92)
                    .frame(maxWidth: .infinity)
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.marbleHigh)
                        .padding(7)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(.trailing, 10)
                }
            }

            VStack(spacing: 4) {
                Text(isNext ? "Следующий ранг" : "Ранг \(rank.rawValue)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(unlocked || isNext ? Palette.gold : Palette.ash)
                Text(rank.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlocked ? Palette.marbleHigh : Palette.marble)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                if let nextProgress {
                    MiniBar(value: nextProgress)
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                }
                if !unlocked {
                    Text("Откроется на \(rank.requiredXP) XP")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.ash)
                }
            }
        }
        .frame(width: 150)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Palette.basalt)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isCurrent ? Palette.gold.opacity(0.8)
                              : isNext ? Palette.gold.opacity(0.3) : Palette.vein,
                              style: StrokeStyle(lineWidth: isCurrent ? 1.5 : 1, dash: isNext ? [4, 3] : []))
        }
    }
}

private struct MiniBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0x24242B))
                Capsule().fill(.goldFill)
                    .frame(width: max(geo.size.width * min(max(value, 0), 1), value > 0 ? 4 : 0))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Подробно о ранге

private struct SpartanDetailSheet: View {
    let rank: SpartanRank
    let progress: AvatarProgressManager

    private var locked: Bool { rank > progress.currentRank }
    private var remaining: Int { max(rank.requiredXP - progress.totalXP, 0) }
    /// Для следующего ранга — доля пути к нему, для дальних — от нуля.
    private var fraction: Double {
        rank == progress.nextRank ? progress.levelProgress
            : min(Double(progress.totalXP) / Double(max(rank.requiredXP, 1)), 1)
    }

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

            if locked {
                VStack(spacing: 10) {
                    HStack {
                        Label("Откроется на \(rank.requiredXP) XP", systemImage: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.marble)
                        Spacer()
                        Text("ещё \(remaining) XP")
                            .font(Face.display(15, .semibold))
                            .foregroundStyle(.goldFill)
                    }
                    MiniBar(value: fraction)
                    Text("Опыт дают челленджи, дни стрика и статьи.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .cardSurface()
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
        .fittedSheet()
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
