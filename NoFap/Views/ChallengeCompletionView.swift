//
//  ChallengeCompletionView.swift
//  NoFap
//

import SwiftUI

struct ChallengeCompletionView: View {
    let onClaim: () -> Void

    @Environment(AvatarProgressManager.self) private var xp
    @State private var burst = false
    @State private var gain: XPGain?

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()

            ConfettiBurst(active: burst)
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.gold)
                    .scaleEffect(burst ? 1 : 0.6)
                    .padding(.top, 28)

                Text("Мощная победа! 🔥")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)

                Text("Вызов закрыт. Следующий уже ждёт.")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.marble)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                // Опыт аватару — прямо здесь, а не за этим окном.
                if let gain {
                    XPGainCard(gain: gain)
                        .padding(.top, 4)
                }

                Button(action: onClaim) {
                    Text("Получить следующий челлендж")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .fittedSheet()
        // Новый ранг — когда окно закрыто, иначе торжество спрячется за ним.
        .onDisappear {
            let gain = gain
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                xp.celebrate(gain)
            }
        }
        .onAppear {
            gain = xp.takeGain()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                burst = true
            }
        }
    }
}

private struct ConfettiBurst: View {
    let active: Bool

    private let pieces: [(x: CGFloat, delay: Double, color: Color)] = [
        (-120, 0.0, Palette.gold),
        (-70, 0.05, .green),
        (-20, 0.02, Palette.goldLight),
        (30, 0.08, .orange),
        (80, 0.03, Palette.gold),
        (130, 0.06, .mint)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                Circle()
                    .fill(piece.color)
                    .frame(width: 10, height: 10)
                    .offset(x: active ? piece.x : 0, y: active ? 220 : -40)
                    .opacity(active ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(piece.delay), value: active)
            }
        }
    }
}
