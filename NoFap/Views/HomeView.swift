//
//  HomeView.swift
//  NoFap
//

import SwiftUI

struct HomeView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak

    @State private var showRelapse = false
    @State private var showGoalReached = false
    @State private var newGoalDraft = 21

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                greeting
                summitCard
                freedomSection
                quoteCard
                actions
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .confirmationDialog(
            "Отметить срыв?",
            isPresented: $showRelapse,
            titleVisibility: .visible
        ) {
            Button("Отметить срыв", role: .destructive) { streak.checkIn(clean: false) }
        } message: {
            Text("Счётчик обнулится, рекорд останется. Отметка нужна только тебе — она никуда не отправляется.")
        }
        .onChange(of: streak.justReachedGoal) { _, reached in
            if reached {
                newGoalDraft = streak.personalGoalDays
                showGoalReached = true
            }
        }
        .sheet(isPresented: $showGoalReached, onDismiss: { streak.acknowledgeGoalReached() }) {
            VStack(spacing: 20) {
                Text("Цель достигнута!")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(.goldFill)

                Text("Ты продержался \(streak.personalGoalDays) \(dayWord(streak.personalGoalDays)) — именно столько сам себе и поставил. Поставь себе новую цель.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                GoalPicker(selected: $newGoalDraft)

                Button("Продолжить") {
                    streak.setGoal(newGoalDraft)
                    showGoalReached = false
                }
                .buttonStyle(GoldButton())
            }
            .padding(24)
            .presentationDetents([.height(520)])
            .presentationBackground(Palette.obsidian)
        }
    }

    // MARK: - Шапка

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Привет, воин")
                    .font(Face.display(24, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(blocking.isActive
                     ? "Защита стоит. Ты здесь, чтобы стать лучше."
                     : "Ты здесь, чтобы стать лучше.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
            }

            Spacer()

            Circle()
                .strokeBorder(Palette.vein, lineWidth: 1)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.marble)
                }
        }
        .padding(.top, 6)
    }

    // MARK: - Стрик

    private var summitCard: some View {
        ZStack {
            Summit()

            VStack(spacing: 0) {
                Eyebrow(text: "твой стрик")
                    .padding(.top, 20)

                Text("\(streak.currentStreak)")
                    .font(Face.display(76, .semibold))
                    .foregroundStyle(.goldFill)
                    .shadow(color: Palette.gold.opacity(0.45), radius: 16)
                    .contentTransition(.numericText())

                Eyebrow(text: dayWord(streak.currentStreak), color: Palette.marble)

                Spacer()

                Text("Лучший стрик: \(streak.bestStreak) \(dayWord(streak.bestStreak)) · Цель: \(streak.personalGoalDays) \(dayWord(streak.personalGoalDays))")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.marble.opacity(0.8))
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 252)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.vein, lineWidth: 1)
        }
    }

    // MARK: - Свобода дня

    /// Без карточки: знаки стоят прямо на фоне и работают как акцент экрана.
    private var freedomSection: some View {
        VStack(spacing: 22) {
            Text("Сегодня ты свободен от:")
                .font(Face.display(22, .medium))
                .foregroundStyle(Palette.marbleHigh)

            HStack(spacing: 52) {
                freedom("Дрочки", asset: "IconMasturbation")
                freedom("Порно", asset: "IconPorn")
            }
        }
        .padding(.vertical, 4)
    }

    private func freedom(_ title: String, asset: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                // Свечение под знаком — тот же источник света, что и на вершине.
                Circle()
                    .fill(Palette.gold.opacity(0.10))
                    .frame(width: 96, height: 96)
                    .blur(radius: 14)

                Circle()
                    .strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1.8)
                    .frame(width: 92, height: 92)

                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.goldFill)

                // Перечёркивание — состояние, а не часть иконки.
                Capsule()
                    .fill(.goldFill)
                    .frame(width: 92, height: 2)
                    .rotationEffect(.degrees(-45))
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.marble)
        }
    }

    // MARK: - Цитата

    private var quoteCard: some View {
        Text("«\(Motivations.today())»")
            .font(Face.quote(16))
            .foregroundStyle(Palette.marble.opacity(0.9))
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Действия

    @ViewBuilder
    private var actions: some View {
        if streak.hasCheckedInToday {
            Text("Сегодня ты держишься")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .frame(height: 56)
                .padding(.top, 6)
        } else {
            VStack(spacing: 14) {
                Button("Я ДЕРЖУСЬ") { streak.checkIn(clean: true) }
                    .buttonStyle(GoldButton())

                Button("Сообщить о срыве") { showRelapse = true }
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
            }
            .padding(.top, 6)
        }
    }

    private func dayWord(_ n: Int) -> String {
        let mod100 = n % 100, mod10 = n % 10
        if (11...14).contains(mod100) { return "дней" }
        return switch mod10 {
        case 1: "день"
        case 2...4: "дня"
        default: "дней"
        }
    }
}

// MARK: - Общие элементы

extension View {
    /// Поверхность карточки: чуть светлее фона плюс тонкая граница.
    func cardSurface() -> some View {
        background(Palette.basalt, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.vein, lineWidth: 1)
            }
    }
}

/// Главное действие — единственная сплошная золотая заливка в приложении.
struct GoldButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color(hex: 0x1A1405))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(.goldFill))
            .shadow(color: Palette.gold.opacity(0.28), radius: 14, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Тёмный камень: холодный низ, чуть более тёплый верх, лёгкая виньетка.
struct StoneBackground: View {
    var body: some View {
        ZStack {
            Palette.obsidian
            RadialGradient(
                colors: [Palette.basalt.opacity(0.9), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 40,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

/// Кнопка-гравировка: не заливка, а тонкий золотой контур.
struct EngravedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(.goldFill)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                Capsule().fill(Palette.gold.opacity(configuration.isPressed ? 0.14 : 0.06))
            }
            .overlay {
                Capsule().strokeBorder(Palette.gold.opacity(0.45), lineWidth: 1)
            }
    }
}

/// Второстепенное действие — без золота, только камень.
struct StoneButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(Palette.ash)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay {
                Capsule().strokeBorder(Palette.vein, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
