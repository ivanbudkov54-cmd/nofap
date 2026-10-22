//
//  TourOverlayView.swift
//  NoFap
//

import SwiftUI

struct TourOverlayView: View {

    @Environment(AppTourManager.self) private var tour
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            spotlight
            if tour.step != .finish {
                Button("Пропустить") { tour.skipTour() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .overlay { Capsule().strokeBorder(Palette.vein, lineWidth: 1) }
                    .padding(.trailing, 18)
                    .padding(.top, 4)
            }
        }
    }

    private var spotlight: some View {
        GeometryReader { geo in
            let holes = tour.spotlightVisible && tour.step != .finish ? (tour.frames[tour.step] ?? []) : []
            let holeScale: CGFloat = tour.spotlightVisible ? 1 : 0.9
            ZStack {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .reverseMask {
                        ForEach(Array(holes.enumerated()), id: \.offset) { _, hole in
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .frame(width: hole.width + 16, height: hole.height + 16)
                                .scaleEffect(holeScale)
                                .position(x: hole.midX, y: hole.midY)
                        }
                    }

                ForEach(Array(holes.enumerated()), id: \.offset) { _, hole in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.gold, lineWidth: 2)
                        .frame(width: hole.width + 16, height: hole.height + 16)
                        .scaleEffect(holeScale * (pulse ? 1.025 : 1))
                        .position(x: hole.midX, y: hole.midY)
                }
                .opacity(tour.spotlightVisible ? 1 : 0)

                if tour.step == .sisyphus, let focus = tour.pulseFrame {
                    SisyphusPulse(pulse: pulse)
                        .frame(width: focus.width, height: focus.height)
                        .position(x: focus.midX, y: focus.midY)
                        .opacity(tour.spotlightVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }

                TourTooltipCard(step: tour.step, onNext: { tour.nextStep() })
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 18)
                    .opacity(tour.spotlightVisible ? 1 : 0)
                    .scaleEffect(tour.spotlightVisible ? 1 : 0.96)
                    .position(cardPosition(in: geo.size, holes: holes))
            }
            .animation(.spring(duration: 0.45, bounce: 0.18), value: tour.spotlightVisible)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func cardPosition(in size: CGSize, holes: [CGRect]) -> CGPoint {
        guard tour.step != .finish, let union = holes.nonEmptyUnion else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let cardHeight: CGFloat = tour.step == .sisyphus ? 300 : 230

        // Подсветок бывает несколько: карточка встаёт в первый свободный
        // промежуток рядом с любой из них, чтобы не закрыть другую.
        let candidates = holes.flatMap { [$0.maxY + 24 + cardHeight / 2, $0.minY - 24 - cardHeight / 2] }
        for y in candidates where y - cardHeight / 2 > 12 && y + cardHeight / 2 < size.height - 12 {
            let card = CGRect(x: 0, y: y - cardHeight / 2, width: size.width, height: cardHeight)
            if !holes.contains(where: { $0.insetBy(dx: -8, dy: -8).intersects(card) }) {
                return CGPoint(x: size.width / 2, y: y)
            }
        }

        let below = union.maxY + 24 + cardHeight / 2
        let above = union.minY - 24 - cardHeight / 2
        let y: CGFloat
        if below + cardHeight / 2 < size.height - 12 {
            y = below
        } else if above - cardHeight / 2 > 12 {
            y = above
        } else {
            y = size.height - cardHeight / 2 - 24
        }
        return CGPoint(x: size.width / 2, y: min(max(y, cardHeight / 2 + 12), size.height - cardHeight / 2 - 12))
    }
}

/// Мягкое золотое свечение вокруг камня и Сизифа: два кольца расходятся
/// и гаснут, пока шаг открыт.
private struct SisyphusPulse: View {
    let pulse: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(Palette.gold.opacity(pulse ? 0.15 : 0.55), lineWidth: 2)
                .scaleEffect(pulse ? 1.12 : 0.96)
            Ellipse()
                .stroke(Palette.goldLight.opacity(pulse ? 0.35 : 0.8), lineWidth: 1.5)
                .scaleEffect(pulse ? 1.02 : 0.9)
                .shadow(color: Palette.gold.opacity(0.6), radius: pulse ? 14 : 6)
        }
    }
}

private struct TourTooltipCard: View {
    let step: AppTourStep
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let index = step.spotlightIndex {
                Text("Шаг \(index) из \(AppTourStep.spotlightCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                HStack(spacing: 6) {
                    ForEach(1...AppTourStep.spotlightCount, id: \.self) { dot in
                        Circle()
                            .fill(dot <= index ? Palette.gold : Palette.vein)
                            .frame(width: 7, height: 7)
                    }
                }
            }

            Text(step.title)
                .font(Face.display(20, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.detail)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)

            if step == .finish {
                Button(action: onNext) {
                    Text("В бой!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.goldSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else if step == .sisyphus {
                Button(action: onNext) {
                    Text(step.nextLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.goldSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                HStack {
                    Spacer()
                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text(step.nextLabel)
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.goldSurface, in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.vein, lineWidth: 1)
        }
    }
}

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

private extension Array where Element == CGRect {
    var nonEmptyUnion: CGRect? {
        guard let first else { return nil }
        return dropFirst().reduce(first) { $0.union($1) }
    }
}
