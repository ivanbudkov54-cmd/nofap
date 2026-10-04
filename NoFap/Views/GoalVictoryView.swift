//
//  GoalVictoryView.swift
//  NoFap
//

import SwiftUI

struct GoalVictoryView: View {
    let targetDays: Int
    var onRaise: () -> Void
    var onJournal: () -> Void
    var onStay: () -> Void

    @State private var appear = false
    @State private var pulse = false

    private var target: StreakTarget? { StreakTarget(rawValue: targetDays) }

    var body: some View {
        ZStack {
            Color(hex: 0x07070A).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: 0xF0BC4F).opacity(0.45), Color(hex: 0x07070A)],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
            VictorySparks(active: appear)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(hex: 0xF0BC4F))
                        .scaleEffect(pulse ? 1.06 : 0.94)
                        .padding(.top, 28)

                    Text("РУБЕЖ ПРЕОДОЛЁН")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color(hex: 0xF0BC4F))

                    Text("Ты покорил планку в \(targetDays) дней! ⚔️")
                        .font(Face.display(26, .semibold))
                        .foregroundStyle(Color(hex: 0xF2F2F5))
                        .multilineTextAlignment(.center)

                    Text(l10n: subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: 0xC8C8D0))
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Твоя энергия теперь принадлежит тебе", systemImage: "flame.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF0BC4F))
                        Text("Ты вышел из рабства экранной гиперстимуляции. Твоя сексуальная энергия — это не враг, а чистая витальная сила. Направляй её в реальную жизнь: спорт, бизнес, харизму и живые отношения с реальными девушками. Не отдавай эту победу обратно пикселям.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: 0xE4E7EF))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button("Поднять планку стрика 🚀", action: onRaise)
                        .buttonStyle(GoldButton())

                    Button("Зафиксировать триумф в Дневнике 📌", action: onJournal)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF2F2F5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0x2A2A32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button("Остаться на текущем уровне", action: onStay)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: 0xA0A0AA))
                        .padding(.bottom, 12)
                }
                .padding(24)
                .scaleEffect(appear ? 1 : 0.94)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appear = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var subtitle: String {
        switch target {
        case .breakout:
            "Разрыв цепи завершён. Ты доказал, что сильнее сиюминутного рефлекса."
        case .clarity:
            "Дофаминовый детокс пройден. Твой разум чист, а фокус возвращён."
        case .reset:
            "Глубокая перезагрузка состоялась. Твоя андрогенная система перекалибрована."
        case .sovereign:
            "Уровень Титана. Нейропластичность закрепила абсолютный контроль над импульсами."
        case nil:
            "Рубеж взят. Двигайся дальше."
        }
    }
}

private struct VictorySparks: View {
    let active: Bool
    private let pieces: [(CGFloat, Double)] = [(-120, 0), (-60, 0.05), (0, 0.02), (60, 0.08), (120, 0.03)]

    var body: some View {
        ZStack {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                Circle()
                    .fill(Color(hex: 0xF0BC4F))
                    .frame(width: 8, height: 8)
                    .offset(x: active ? piece.0 : 0, y: active ? 180 : -30)
                    .opacity(active ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(piece.1), value: active)
            }
        }
    }
}
