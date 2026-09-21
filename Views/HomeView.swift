//
//  HomeView.swift
//  NoFap
//

import SwiftUI

struct HomeView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak

    @State private var showRelapse = false
    @State private var showSOSRelapse = false
    @State private var showGoalReached = false
    @State private var showSOS = false
    @State private var sosPath: [SOSOption] = []
    @State private var newGoalDraft = 21

    /// Три способа переждать тягу — выбор, а не один навязанный сценарий.
    /// .survey — общий финальный шаг для всех трёх, шагом дальше по стеку.
    private enum SOSOption: Hashable {
        case breathing, exercise, motivation, survey
    }

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
            .padding(.bottom, 170)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .confirmationDialog(
            "Отметить срыв?",
            isPresented: $showRelapse,
            titleVisibility: .visible
        ) {
            Button("Отметить срыв", role: .destructive) {
                withAnimation { _ = streak.checkIn(clean: false) }
            }
        } message: {
            Text("Счётчик обнулится, рекорд останется. Отметка нужна только тебе — она никуда не отправляется.")
        }
        // Отдельное подтверждение для кнопки под SOS — тот же сброс стрика,
        // но с переходом в опрос про триггер сразу после, а не молча.
        .confirmationDialog(
            "Отметить срыв?",
            isPresented: $showSOSRelapse,
            titleVisibility: .visible
        ) {
            Button("Отметить срыв", role: .destructive) {
                withAnimation { _ = streak.checkIn(clean: false) }
                sosPath = [.survey]
                showSOS = true
            }
        } message: {
            Text("Счётчик обнулится, рекорд останется. Дальше — короткий вопрос о причине, чтобы в следующий раз узнать её заранее.")
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
        .sheet(isPresented: $showSOS, onDismiss: { sosPath = [] }) {
            NavigationStack(path: $sosPath) {
                sosMenu
                    .navigationDestination(for: SOSOption.self) { option in
                        switch option {
                        case .breathing:  breathingView
                        case .exercise:   exerciseView
                        case .motivation: motivationView
                        case .survey:     triggerSurvey
                        }
                    }
            }
            .presentationDetents([.height(560), .large])
            .presentationBackground(Palette.obsidian)
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - SOS

    /// Точка входа на случай острой тяги: три равноценных пути, а не один
    /// навязанный совет — то, что откликнется, у всех разное.
    private var sosMenu: some View {
        VStack(spacing: 22) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 34))
                .foregroundStyle(.red)
                .padding(.top, 12)

            Text("Стоп. Тяга — это волна")
                .font(Face.display(24, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .multilineTextAlignment(.center)

            Text("Она поднимается и всегда спадает. Выбери, что поможет продержаться следующие пару минут.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            VStack(spacing: 12) {
                sosRow(icon: "wind", title: "Дыхательная практика",
                       subtitle: "Снять напряжение за 3 круга дыхания", option: .breathing)
                sosRow(icon: "figure.strengthtraining.traditional", title: "Физическое упражнение",
                       subtitle: "Переключить тело прямо сейчас", option: .exercise)
                sosRow(icon: "quote.opening", title: "Мотивация",
                       subtitle: "Вспомнить, зачем ты это делаешь", option: .motivation)
            }
            .padding(.horizontal, 4)

            Spacer()

            Button("Закрыть") { showSOS = false }
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func sosRow(icon: String, title: String, subtitle: String, option: SOSOption) -> some View {
        Button {
            sosPath.append(option)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.red)
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.10), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Face.display(14, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            }
            .padding(14)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    // MARK: - SOS · Дыхательная практика

    @State private var breathPhase: BreathPhase = .inhale
    @State private var breathScale: CGFloat = 0.62

    private enum BreathPhase: String {
        case inhale = "Вдох", hold = "Задержи", exhale = "Выдох"
    }

    private var breathingView: some View {
        VStack(spacing: 26) {
            Text("Дыхательная практика")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .padding(.top, 8)

            Text("4 секунды вдох — 4 секунды задержка — 6 секунд выдох. Три круга снимают острую тягу.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.10))
                    .frame(width: 180, height: 180)

                Circle()
                    .strokeBorder(Color.red.opacity(0.6), lineWidth: 1.6)
                    .frame(width: 150, height: 150)
                    .scaleEffect(breathScale)

                Text(breathPhase.rawValue)
                    .font(Face.display(18, .medium))
                    .foregroundStyle(Palette.marbleHigh)
            }
            .frame(height: 190)
            .task { await runBreathingCycle() }

            Spacer()

            Button("Стало легче") { sosPath.append(.survey) }
                .buttonStyle(GoldButton())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    /// Крутится, пока экран открыт — SwiftUI сам отменит Task при уходе с экрана.
    private func runBreathingCycle() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 4)) {
                breathPhase = .inhale
                breathScale = 1.0
            }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            breathPhase = .hold
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 6)) {
                breathPhase = .exhale
                breathScale = 0.62
            }
            try? await Task.sleep(for: .seconds(6))
        }
    }

    // MARK: - SOS · Физическое упражнение

    private var exerciseView: some View {
        VStack(spacing: 22) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .padding(.top, 8)

            Text("Физическое упражнение")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)

            Text("Тело переключает мозг быстрее, чем уговоры. Сделай один из вариантов прямо сейчас.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 10) {
                bulletTip("20 приседаний")
                bulletTip("15 отжиманий")
                bulletTip("Бег на месте 2 минуты")
                bulletTip("Холодная вода на лицо или запястья")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardSurface()
            .padding(.horizontal, 4)

            Spacer()

            Button("Сделал, стало легче") { sosPath.append(.survey) }
                .buttonStyle(GoldButton())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - SOS · Мотивация

    private var motivationView: some View {
        let reasons = UserDefaults.standard.stringArray(forKey: "selectedReasons") ?? []

        return VStack(spacing: 22) {
            Image(systemName: "quote.opening")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .padding(.top, 8)

            Text("Вспомни, зачем")
                .font(Face.display(22, .semibold))
                .foregroundStyle(Palette.marbleHigh)

            Text("«\(Motivations.today())»")
                .font(Face.quote(17))
                .foregroundStyle(Palette.marble)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(reasons, id: \.self) { bulletTip($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardSurface()
                .padding(.horizontal, 4)
            }

            Spacer()

            Button("Держусь дальше") { sosPath.append(.survey) }
                .buttonStyle(GoldButton())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - SOS · Опрос о триггере

    /// Финальный шаг после любой из трёх практик: один вопрос, ответ сразу
    /// закрывает SOS — без промежуточного «Готово», чтобы не растягивать
    /// момент, когда тяга уже отпустила.
    private var triggerSurvey: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Что стало триггером?")
                    .font(Face.display(22, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(Trigger.allCases) { trigger in
                        triggerRow(trigger)
                    }
                }

                Button("Пропустить") { showSOS = false }
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func triggerRow(_ trigger: Trigger) -> some View {
        Button {
            TriggerLog.record(trigger)
            showSOS = false
        } label: {
            HStack(spacing: 14) {
                Text(trigger.emoji)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trigger.title)
                        .font(Face.display(14, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                    Text(trigger.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func bulletTip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("—").foregroundStyle(.red)
            Text(text).foregroundStyle(Palette.marble)
        }
        .font(.system(size: 14))
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
        // SOS должен оставаться на экране в любом состоянии — тяга не
        // спрашивает, отмечался ли человек сегодня, поэтому кнопка вынесена
        // из ветки if/else, а не дублируется в обеих.
        VStack(spacing: 14) {
            // TimelineView тикает раз в 30 секунд сам по себе — обратный
            // отсчёт живой, без ручного Timer и @State в HomeView. Чаще не
            // нужно: таймер показывает только часы и минуты.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                if let remaining = streak.relapseCooldownRemaining(at: context.date) {
                    relapseCooldownCard(remaining)
                } else if streak.hasCheckedInToday {
                    Text("Сегодня ты держишься")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ash)
                        .padding(.top, 6)
                } else {
                    VStack(spacing: 14) {
                        // withAnimation обязателен: без него .contentTransition(.numericText())
                        // не анимирует смену цифры стрика.
                        Button("Я ДЕРЖУСЬ") {
                            withAnimation { _ = streak.checkIn(clean: true) }
                        }
                            .buttonStyle(GoldButton())

                        Button("Сообщить о срыве") { showRelapse = true }
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.ash)
                    }
                }
            }

            Button("SOS") { showSOS = true }
                .buttonStyle(SOSButton())

            Button("Сорвался") { showSOSRelapse = true }
                .buttonStyle(StoneButton())
        }
        .padding(.top, 6)
    }

    /// Заметная карточка вместо мелкой подписи — с иконкой замка и
    /// тикающим по секундам таймером ЧЧ:ММ:СС до момента, когда снова
    /// станет доступна кнопка "Я ДЕРЖУСЬ".
    private func relapseCooldownCard(_ remaining: TimeInterval) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Ты отметил срыв. «Я ДЕРЖУСЬ» снова станет доступна через:")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.ash)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text(countdownString(remaining))
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .cardSurface()
    }

    /// "05:12" — часы:минуты до конца суточного кулдауна.
    private func countdownString(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded(.up)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
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

/// Экстренная кнопка: единственный красный элемент в приложении — острая
/// тяга требует немедленного, а не «выученного» внимания.
struct SOSButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(Color.red.opacity(configuration.isPressed ? 0.75 : 0.9)))
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
    }
}
