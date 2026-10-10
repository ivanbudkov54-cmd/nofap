//
//  ChallengesView.swift
//  NoFap
//

import SwiftUI

struct ChallengesView: View {

    @Environment(ChallengeManager.self) private var challenges
    @Environment(AvatarManager.self) private var avatar
    @Environment(AvatarProgressManager.self) private var xp
    @State private var completionGain: XPGain?

    @Environment(AppTourManager.self) private var tour

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Челленджи")
                    .font(Face.display(28, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .padding(.top, 8)

                ContrastExperimentView()

                stats

                activeCard

                history
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // Своя шапка вместо панели навигации — у всех вкладок одна высота.
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: tour.currentStepIndex) { _, _ in
            guard tour.isTourActive, tour.step == .challenges else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("tour-challenge", anchor: .center)
            }
        }
        .sheet(isPresented: Bindable(challenges).showCompletion) {
            ChallengeCompletionView(gain: completionGain) {
                challenges.showCompletion = false
            }
        }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat(title: "Уровень", value: "\(challenges.level)")
            stat(title: "Закрыто", value: "\(challenges.totalCompletedChallengesCount)")
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.ash)
            Text(value)
                .font(Face.display(20, .semibold))
                .foregroundStyle(Palette.marbleHigh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardSurface()
    }

    private var activeCard: some View {
        let item = challenges.current
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.marble)
                Spacer()
                Text(item.difficulty.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(difficultyColor(item.difficulty))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(difficultyColor(item.difficulty).opacity(0.16), in: Capsule())
            }

            Text(item.title)
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.subtitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.gold)

            Text(item.detail)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .fixedSize(horizontal: false, vertical: true)

            // Одно нажатие — без «вы уверены?»: это не необратимое действие,
            // а отметка о победе.
            Button {
                completeChallenge()
            } label: {
                Text("Выполнил вызов")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.goldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .cardSurface()
        .id("tour-challenge")
        .tourTarget(.challenges)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История выполненных вызовов")
                .font(Face.display(18, .semibold))
                .foregroundStyle(Palette.marbleHigh)

            if challenges.completedItems.isEmpty {
                Text("Пока пусто. Закрой текущий вызов — он появится здесь.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
            } else {
                ForEach(Array(challenges.completedItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.marbleHigh)
                            Text(item.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.ash)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .cardSurface()
                }
            }
        }
    }

    private func completeChallenge() {
        // Сложный или социальный вызов ценится выше — берём его
        // до завершения: потом `current` уже следующий.
        let item = challenges.current
        let isHard = item.difficulty == .hard || item.category == "Социальная смелость"
        // Награда показывается в окне «Мощная победа» — забираем её до
        // того, как всплыла бы отдельная карточка.
        xp.rewardChallengeCompleted(isHard: isHard)
        completionGain = xp.takeGain()
        avatar.addPowerForChallenge()
        challenges.completeCurrentChallenge()
    }

    private func difficultyColor(_ difficulty: ChallengeItem.Difficulty) -> Color {
        switch difficulty {
        case .easy: .green
        case .medium: Palette.gold
        case .hard: .red
        }
    }
}
