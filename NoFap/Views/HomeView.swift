//
//  HomeView.swift
//  NoFap
//

import SwiftUI

struct HomeView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner

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
            // Обнуление — деликатный момент, поэтому медленнее отметки: число
            // должно осесть, а не щёлкнуть.
            Button("Отметить срыв", role: .destructive) {
                withAnimation(.snappy(duration: 0.4)) { _ = streak.checkIn(clean: false) }
            }
        } message: {
            // Текст зависит от того, есть ли напарник: обещать «никуда не
            // отправляется», когда счёт видит другой человек, — враньё.
            Text(relapseNote)
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

                Text("Ты продержался \(streak.personalGoalDays.daysCount) — именно столько сам себе и поставил. Поставь себе новую цель.")
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

    /// Тернарник из строковых литералов Swift выводит как `String`, и такой
    /// текст не попадает в каталог локализации. Явный тип это чинит.
    private var relapseNote: LocalizedStringResource {
        partner.isPaired
            ? "Счётчик обнулится, рекорд останется. Напарник увидит, что счёт начался заново, но не узнает причину."
            : "Счётчик обнулится, рекорд останется. Отметка нужна только тебе — она никуда не отправляется."
    }

    private var greetingNote: LocalizedStringResource {
        blocking.isActive ? "Защита стоит. Ты здесь, чтобы стать лучше." : "Ты здесь, чтобы стать лучше."
    }

    // MARK: - Шапка

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Привет, воин")
                    .font(Face.display(24, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(greetingNote)
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
            // Фото подогнано впритык под рамку карточки — без запаса сверху
            // и снизу сдвинуть его нельзя, обнажится пустой край. `offset`
            // именно это и делал — отодвигал картинку, оставляя пустоту.
            // Зум так не может: он только растит картинку за рамку, а якорь
            // решает, куда она растёт. Якорь снизу — растёт вверх, и гора
            // с фигурой поднимаются к центру карточки. Значение подобрано
            // под этот кадр: фигура должна стоять между словом под числом
            // и нижней строкой, не наезжая ни на одно.
            Image("MountainSummit")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(1.25, anchor: .bottom)
                .clipped()
                // Тёмная плёнка сверху — тот же приём, что и у векторного
                // фона: числу и подписям нужен контраст поверх сцены.
                .overlay {
                    LinearGradient(
                        colors: [Palette.obsidian.opacity(0.35), Palette.obsidian.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

            VStack(spacing: 0) {
                Eyebrow(text: "твой стрик", color: Palette.marble)
                    .padding(.top, 20)

                Text("\(streak.currentStreak)")
                    .font(Face.display(76, .semibold))
                    .foregroundStyle(.goldFill)
                    .shadow(color: Palette.gold.opacity(0.45), radius: 16)
                    .contentTransition(.numericText())

                Eyebrow(verbatim: streak.currentStreak.dayWord, color: Palette.marble)

                Spacer()

                Text("Лучший стрик: \(streak.bestStreak.daysCount) · Цель: \(streak.personalGoalDays.daysCount)")
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

    private func freedom(_ title: LocalizedStringResource, asset: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                // Свечение под знаком — тот же источник света, что и на вершине.
                Circle()
                    .fill(Palette.gold.opacity(0.10))
                    .frame(width: 96, height: 96)
                    .blur(radius: 14)

                Image(asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.goldFill)

                // Перечёркивание — состояние, а не часть иконки. Чёрная
                // подложка чуть шире полосы — это обводка снаружи: золото
                // остаётся целиком, а линия отделяется от золотых штрихов
                // самой иконки (у IconPorn один штрих X идёт под тем же углом).
                ZStack {
                    Capsule()
                        .fill(.black)
                        .frame(width: 92, height: 4)
                    Capsule()
                        .fill(.goldFill)
                        .frame(width: 92, height: 2)
                }
                .rotationEffect(.degrees(-45))

                // Кольцо — последним, поверх полосы: тогда чёрная обводка
                // полосы уходит под кольцо, а её золото перетекает в золото
                // кольца. Иначе обводка резала кольцо в местах стыка, и
                // полоса выглядела положенной сверху, а не частью знака.
                Circle()
                    .strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1.8)
                    .frame(width: 92, height: 92)
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
                // Без транзакции `.contentTransition(.numericText())` на числе
                // стрика не срабатывает — число просто перещёлкивалось. Это
                // главный момент награды в приложении, он должен перекатиться.
                Button("Я ДЕРЖУСЬ") {
                    withAnimation(.snappy(duration: 0.25)) { _ = streak.checkIn(clean: true) }
                }
                .buttonStyle(GoldButton())

                Button("Сообщить о срыве") { showRelapse = true }
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
            }
            .padding(.top, 6)
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
            // Та же реакция на нажатие, что у GoldButton: три стиля кнопок не
            // должны вести себя по-разному.
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
