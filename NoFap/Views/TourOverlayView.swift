//
//  TourOverlayView.swift
//  NoFap
//

import SwiftUI

struct TourOverlayView: View {

    @Environment(AppTourManager.self) private var tour
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let holes = tour.spotlightVisible && tour.step != .finish ? (tour.frames[tour.step] ?? []) : []
            ZStack {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.32), value: tour.spotlightVisible)
                    .reverseMask {
                        ForEach(Array(holes.enumerated()), id: \.offset) { _, hole in
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .frame(width: hole.width + 16, height: hole.height + 16)
                                .position(x: hole.midX, y: hole.midY)
                        }
                    }

                ForEach(Array(holes.enumerated()), id: \.offset) { _, hole in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.gold, lineWidth: 2)
                        .frame(width: hole.width + 16, height: hole.height + 16)
                        .position(x: hole.midX, y: hole.midY)
                        .scaleEffect(pulse ? 1.025 : 1)
                }
                .opacity(tour.spotlightVisible ? 1 : 0)

                TourTooltipCard(step: tour.step, onNext: { tour.nextStep() }, onSkip: { tour.skipTour() })
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 18)
                    .opacity(tour.spotlightVisible ? 1 : 0)
                    .position(cardPosition(in: geo.size, holes: holes))
            }
            .animation(.easeInOut(duration: 0.32), value: tour.spotlightVisible)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func cardPosition(in size: CGSize, holes: [CGRect]) -> CGPoint {
        guard tour.step != .finish, let union = holes.nonEmptyUnion else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let cardHeight: CGFloat = 230
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

private struct TourTooltipCard: View {
    let step: AppTourStep
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let index = step.spotlightIndex {
                Text("Шаг \(index) из 5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { dot in
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
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                HStack {
                    Button("Пропустить", action: onSkip)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.ash)
                    Spacer()
                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text("Далее")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Palette.gold, in: Capsule())
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
