//
//  XPGainToast.swift
//  NoFap
//
//  Карточка награды: после «Держусь», челленджа или статьи снизу выезжает
//  аватар, «+50 XP» и полоса опыта, которая на глазах заполняется. Если
//  начисление открыло новый ранг, полоса доходит до конца, и только потом
//  открывается полноэкранное торжество.
//

import SwiftUI

/// Содержимое награды: аватар, «+N XP» и полоса, которая заполняется на
/// глазах. Используется и во всплывающей карточке, и внутри окон вроде
/// «Мощная победа», чтобы награда не пряталась за ними.
struct XPGainCard: View {

    let gain: XPGain

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: Double = 0
    @State private var bump = 0

    private var startRank: SpartanRank { .forXP(gain.fromXP) }

    private func fraction(for xp: Int, in rank: SpartanRank) -> Double {
        guard let next = rank.next else { return 1 }
        let span = Double(next.requiredXP - rank.requiredXP)
        guard span > 0 else { return 1 }
        return min(max(Double(xp - rank.requiredXP) / span, 0), 1)
    }

    private var startFill: Double { fraction(for: gain.fromXP, in: startRank) }
    private var endFill: Double { gain.rankUp != nil ? 1 : fraction(for: gain.toXP, in: startRank) }

    private var caption: String {
        if let rank = gain.rankUp {
            return String(localized: "Новый ранг: \(String(localized: rank.title))")
        }
        guard let next = startRank.next else { return String(localized: "Высший ранг") }
        let left = max(next.requiredXP - gain.toXP, 0)
        return String(localized: "До «\(String(localized: next.title))» — \(left) XP")
    }

    var body: some View {
        HStack(spacing: 14) {
            SpartanFigure(rank: startRank, size: 64)
                .keyframeAnimator(initialValue: 1.0, trigger: bump) { content, scale in
                    content.scaleEffect(scale, anchor: .bottom)
                } keyframes: { _ in
                    SpringKeyframe(1.18, duration: 0.18)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: gain.source.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                    Text(gain.source.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.marble)
                    Spacer(minLength: 4)
                    Text("+\(gain.amount) XP")
                        .font(Face.display(17, .semibold))
                        .foregroundStyle(.goldFill)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0x24242B))
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.goldLight, Palette.gold],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * fill, 8))
                            .shadow(color: Palette.gold.opacity(0.5), radius: 6)
                    }
                }
                .frame(height: 8)

                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(gain.rankUp != nil ? Palette.gold : Palette.ash)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Palette.basalt, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .task(id: gain.id) {
            fill = startFill
            try? await Task.sleep(for: .milliseconds(350))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.0)) { fill = endFill }
            try? await Task.sleep(for: .milliseconds(1000))
            if !reduceMotion { bump += 1 }
        }
    }
}

/// Всплывающая снизу карточка награды — сама уезжает через пару секунд.
struct XPGainToast: View {

    let gain: XPGain
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        XPGainCard(gain: gain)
            .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            .padding(.horizontal, 16)
            .offset(y: shown ? 0 : 160)
            .opacity(shown ? 1 : 0)
            .onTapGesture { close() }
            .gesture(DragGesture(minimumDistance: 10).onEnded { if $0.translation.height > 20 { close() } })
            .accessibilityAddTraits(.isButton)
            .task(id: gain.id) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { shown = true }
                try? await Task.sleep(for: .milliseconds(gain.rankUp != nil ? 2100 : 3200))
                close()
            }
    }

    private func close() {
        guard shown else { return }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) { shown = false }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            onFinish()
        }
    }
}
