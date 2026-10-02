//
//  GolemScreen.swift
//  NoFap
//
//  Кинцуги-голем: каменный страж, которого золото собирает по трещинам.
//  Прогресс — доля пути к личной цели (дни стрика / цель), а не номер дня:
//  цель в 3 дня и в 90 одинаково заполняет его от пустого до целиком
//  золотого, и при любой цели каждый день видно новое золото.
//
//  Прототип: пока одна поза — пустая и золотая версии одного кадра. Позы
//  по порогам (разбит → поднимается → на колене → стоит) подставятся, когда
//  будут картинки; механика маски от этого не меняется.
//

import SwiftUI

/// Прогресс голема — только из стрика и цели, ничего не хранит сам.
struct GolemProgress: Equatable {
    let days: Int
    let goal: Int

    /// 0…1. Без цели считаем от 21 дня — так же, как цель по умолчанию.
    var fraction: Double {
        let target = max(goal, 1)
        return min(Double(days) / Double(target), 1)
    }

    var percent: Int { Int((fraction * 100).rounded()) }
    var isComplete: Bool { fraction >= 1 }

    /// Названия будущих поз — пороги те же, что будут у картинок.
    var stageTitle: LocalizedStringResource {
        switch fraction {
        case ..<0.2:  "Разбит"
        case ..<0.45: "Поднимается"
        case ..<0.7:  "На колене"
        case ..<1:    "Стоит"
        default:      "Собран"
        }
    }
}

/// Сам голем: пустой камень, поверх — золотая версия, проявленная маской
/// от сердца наружу ровно на `fraction`.
struct GolemFigure: View {

    /// Уже анимируемое значение 0…1.
    var fraction: Double

    /// Сердце голема в долях кадра — отсюда расходится золото.
    private static let heart = UnitPoint(x: 0.5, y: 0.3)
    /// Расстояние от сердца до дальнего угла кадра: при 1.0 золото покрывает всё.
    private static let fullRadius = 0.88

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = max(0.0001, fraction * Self.fullRadius) * side

            ZStack {
                // Тёплое свечение за спиной растёт вместе с золотом.
                Image("GolemGold")
                    .resizable()
                    .scaledToFit()
                    .blur(radius: side * 0.06)
                    .opacity(0.45 * fraction)

                Image("GolemEmpty")
                    .resizable()
                    .scaledToFit()

                Image("GolemGold")
                    .resizable()
                    .scaledToFit()
                    .mask {
                        // Мягкий край: золото не обрывается линией, а
                        // «натекает» в трещины.
                        RadialGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.82),
                                .init(color: .clear, location: 1),
                            ],
                            center: Self.heart,
                            startRadius: 0,
                            endRadius: radius
                        )
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Фон картинки чуть светлее нашего — края растворяются в экран,
            // чтобы не проступал квадрат.
            .mask {
                RadialGradient(colors: [.white, .white, .clear],
                               center: .center, startRadius: 0, endRadius: side * 0.56)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct GolemScreen: View {

    @Environment(StreakManager.self) private var streak
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Сколько золота человек видел в прошлый раз — с этого места золото
    /// и натекает при входе, чтобы новый день был заметен глазами.
    @AppStorage("golem.shownFraction") private var shownFraction = 0.0

    @State private var displayed = 0.0
    #if DEBUG
    @State private var preview: Double?
    #endif

    private var progress: GolemProgress {
        GolemProgress(days: streak.currentStreak, goal: streak.personalGoalDays)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                GolemFigure(fraction: displayed)
                    .padding(.horizontal, 4)

                stats

                Text(caption)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                #if DEBUG
                debugScrubber
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle("Голем")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { revealNewGold() }
        .onChange(of: progress) { _, _ in revealNewGold() }
    }

    // MARK: - Части

    private var header: some View {
        VStack(spacing: 6) {
            Eyebrow(text: "кинцуги-голем", color: Palette.gold)
            Text(progress.stageTitle)
                .font(Face.display(28, .semibold))
                .foregroundStyle(progress.isComplete ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.marbleHigh))
                .contentTransition(.opacity)
        }
        .padding(.top, 8)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat(value: "\(Int((displayed * 100).rounded()))%", label: "золота")
            stat(value: "\(progress.days) из \(max(progress.goal, 1))", label: "дней к цели")
        }
    }

    private func stat(value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Face.display(24, .semibold))
                .foregroundStyle(.goldFill)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardSurface()
    }

    private var caption: LocalizedStringResource {
        if progress.isComplete {
            return "Цель взята — голем собран целиком. Поставь новую цель, и золото пойдёт по новому кругу."
        }
        if progress.days == 0 {
            return "Каждый чистый день золото заполняет трещины — от сердца наружу. Нажми «Держусь», чтобы зажечь первую жилу."
        }
        return "Каждый чистый день золото заполняет ещё часть трещин. Срыв гасит его — щит сохраняет."
    }

    // MARK: - Анимация

    /// Золото натекает от того, что человек видел в прошлый раз, к
    /// сегодняшнему. После срыва — так же плавно гаснет.
    private func revealNewGold() {
        var target = progress.fraction
        #if DEBUG
        if let preview { target = preview }
        #endif

        displayed = shownFraction
        guard abs(target - shownFraction) > 0.0001 else { return }

        let grew = target > shownFraction
        let delta = abs(target - shownFraction)
        // Без движения для тех, кто его отключил: золото просто на месте.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8 + 1.6 * min(delta * 3, 1))) {
            displayed = target
        }
        shownFraction = target
        if grew { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }

    #if DEBUG
    /// Только в отладочной сборке: прокрутить прогресс и посмотреть, как
    /// золото заполняет голема при разных целях.
    private var debugScrubber: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Отладка: прогресс")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ash)
            Slider(value: Binding(
                get: { preview ?? progress.fraction },
                set: { value in
                    preview = value
                    displayed = value
                    shownFraction = value
                }
            ), in: 0...1)
            .tint(Palette.gold)
            Button("Сбросить к настоящему") {
                preview = nil
                revealNewGold()
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.gold)
        }
        .padding(14)
        .cardSurface()
    }
    #endif
}
