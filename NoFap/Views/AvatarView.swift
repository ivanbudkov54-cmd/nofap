//
//  AvatarView.swift
//  NoFap
//

import SwiftUI
import UIKit

struct AvatarView: View {

    @Environment(AvatarManager.self) private var avatar
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var breathe = false

    var body: some View {
        if subscriptions.isPro {
            unlocked
        } else {
            locked
        }
    }

    private var unlocked: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                VStack(spacing: 22) {
                    figure
                    stageDots
                    stats
                }
                .tourTarget(.avatar)
                sources
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: evolutionPresented) {
            AvatarEvolutionView(stage: avatar.pendingEvolution ?? avatar.stage) {
                avatar.acknowledgeEvolution()
            }
        }
    }

    private var locked: some View {
        VStack(spacing: 22) {
            Text("Уровень \(avatar.stage.rawValue): \(avatar.stage.title)")
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .frame(maxWidth: .infinity, alignment: .leading)

            figure
                .blur(radius: 8)
                .allowsHitTesting(false)
                .tourTarget(.avatar)

            VStack(spacing: 12) {
                ProLockBadge()
                Text("Аватар и его прокачка доступны в Pro")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)
                Text("Сила, энергия и смена формы открываются вместе с подпиской.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                Button("Открыть Pro") {
                    subscriptions.checkProAccess(for: "Прокачка аватара и смена формы доступны в подписке Pro") {}
                }
                .buttonStyle(GoldButton())
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.obsidian.ignoresSafeArea())
    }

    private var evolutionPresented: Binding<Bool> {
        Binding(
            get: { avatar.pendingEvolution != nil },
            set: { if !$0 { avatar.acknowledgeEvolution() } }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Уровень \(avatar.stage.rawValue): \(avatar.stage.title)")
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)

            Text("⚡️ \(avatar.currentPower) / \(nextLabel) Power")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.gold.opacity(0.14), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var nextLabel: String {
        if let next = avatar.stage.nextThreshold {
            return "\(next)"
        }
        return "\(avatar.stage.floor)+"
    }

    private var figure: some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(0.18 + Double(avatar.currentEnergy) / 100 * 0.55))
                .blur(radius: 18 + CGFloat(avatar.currentEnergy) * 0.22)
                .frame(width: 210 + CGFloat(avatar.currentEnergy) * 0.6, height: 210 + CGFloat(avatar.currentEnergy) * 0.6)

            AvatarFigureView(stage: avatar.stage)
                .frame(height: 280)
                .scaleEffect(breathe ? 1.03 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var glowColor: Color {
        switch avatar.stage {
        case .exhausted: Color(hex: 0x8E93A3)
        case .awakening: Color(hex: 0x9BB7E0)
        case .athlete: Palette.goldLight
        case .warrior: Palette.gold
        case .titan: Color(hex: 0xFF7A2F)
        }
    }

    private var stageDots: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(AvatarStage.allCases) { stage in
                    Circle()
                        .fill(stage.rawValue <= avatar.stage.rawValue ? Palette.gold : Palette.vein)
                        .frame(width: 10, height: 10)
                }
            }
            ProgressView(value: stageProgress)
                .tint(Palette.gold)
            Text(progressCaption)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
    }

    private var stageProgress: Double {
        guard let next = avatar.stage.nextThreshold else { return 1 }
        let span = Double(next - avatar.stage.floor)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(avatar.currentPower - avatar.stage.floor) / span))
    }

    private var progressCaption: String {
        if let next = avatar.stage.nextThreshold {
            return "До следующей формы: \(max(0, next - avatar.currentPower)) силы"
        }
        return "Максимальная форма"
    }

    private var stats: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Сила духа")
                    Spacer()
                    Text("\(avatar.currentPower)")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.marbleHigh)
                ProgressView(value: stageProgress)
                    .tint(Palette.gold)
                    .animation(.easeInOut(duration: 0.45), value: avatar.currentPower)
            }
            .padding(14)
            .cardSurface()

            HStack(spacing: 14) {
                EnergyRing(percent: avatar.currentEnergy)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Текущая энергия")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Text("\(avatar.currentEnergy)%")
                        .font(Face.display(22, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Text("Держится на стрике, вызовах и статьях")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .cardSurface()
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Источники роста")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            sourceRow("Стрик", value: avatar.streakPower)
            sourceRow("Челленджей закрыто", value: avatar.challengePower)
            sourceRow("Статей изучено", value: avatar.articlePower)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
            Spacer()
            Text("+\(value) Power")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.gold)
        }
        .padding(14)
        .cardSurface()
    }
}

struct AvatarFigureView: View {
    let stage: AvatarStage

    var body: some View {
        Group {
            if let image = UIImage(named: "avatar_stage_\(stage.rawValue)") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                procedural
            }
        }
    }

    private var procedural: some View {
        let tone = skin
        let width = shoulder
        return ZStack {
            if stage == .exhausted {
                Ellipse()
                    .fill(Color(hex: 0x8E93A3).opacity(0.28))
                    .frame(width: 150, height: 90)
                    .blur(radius: 16)
                    .offset(y: -20)
            }
            if stage == .titan {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: index.isMultiple(of: 2) ? 0xFF7A2F : 0xF0BC4F).opacity(0.55))
                        .frame(width: 14, height: 14)
                        .offset(x: CGFloat(index - 3) * 22, y: 90)
                        .blur(radius: 1)
                }
            }

            Capsule()
                .fill(tone)
                .frame(width: 16, height: 78)
                .offset(x: -width * 0.28, y: 78)
            Capsule()
                .fill(tone)
                .frame(width: 16, height: 78)
                .offset(x: width * 0.28, y: 78)

            Capsule()
                .fill(tone)
                .frame(width: 18, height: 70)
                .rotationEffect(.degrees(stage == .exhausted ? 28 : 18))
                .offset(x: -width * 0.55, y: 8)
            Capsule()
                .fill(tone)
                .frame(width: 18, height: 70)
                .rotationEffect(.degrees(stage == .exhausted ? -28 : -18))
                .offset(x: width * 0.55, y: 8)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(tone)
                .frame(width: width, height: stage == .exhausted ? 108 : 124)
                .overlay {
                    if stage.rawValue >= 3 {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Palette.gold.opacity(stage == .titan ? 0.9 : 0.45), lineWidth: 2)
                    }
                }

            Circle()
                .fill(tone)
                .frame(width: 58, height: 58)
                .offset(y: stage == .exhausted ? -62 : -84)
                .overlay {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: 0x1A1405).opacity(0.75)).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: 0x1A1405).opacity(0.75)).frame(width: 5, height: 5)
                    }
                    .offset(y: stage == .exhausted ? -58 : -82)
                }
        }
        .rotationEffect(.degrees(stage == .exhausted ? 8 : (stage == .awakening ? 3 : 0)))
        .offset(y: stage == .exhausted ? 18 : 0)
    }

    private var skin: Color {
        switch stage {
        case .exhausted: Color(hex: 0xA7ADBA)
        case .awakening: Color(hex: 0xC9D0DE)
        case .athlete: Color(hex: 0xE7C99A)
        case .warrior: Color(hex: 0xF0BC4F)
        case .titan: Color(hex: 0xF6D48A)
        }
    }

    private var shoulder: CGFloat {
        switch stage {
        case .exhausted: 62
        case .awakening: 72
        case .athlete: 84
        case .warrior: 96
        case .titan: 108
        }
    }
}

private struct EnergyRing: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.vein, lineWidth: 8)
            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.45), value: percent)
            Text("\(percent)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.marbleHigh)
        }
        .frame(width: 72, height: 72)
    }
}

struct AvatarEvolutionView: View {
    let stage: AvatarStage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()
            VStack(spacing: 18) {
                AvatarFigureView(stage: stage)
                    .frame(height: 240)
                Text("Твой аватар эволюционировал!")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)
                Text("Новая физическая форма разблокирована 🔥")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.marble)
                    .multilineTextAlignment(.center)
                Text("Уровень \(stage.rawValue): \(stage.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                Button(action: onClose) {
                    Text("Продолжить")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct ArticleStudiedBar: View {
    let articleID: String

    @Environment(AvatarManager.self) private var avatar

    var body: some View {
        let studied = avatar.hasReadArticle(id: articleID)
        Button {
            avatar.addPowerForArticle(id: articleID)
        } label: {
            Text(studied ? "Уже изучена" : "Статья изучена")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(studied ? Palette.ash : Color(hex: 0x1A1405))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    studied ? AnyShapeStyle(Palette.vein) : AnyShapeStyle(Palette.gold),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .disabled(studied)
    }
}
