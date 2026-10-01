//
//  HomeView.swift
//  NoFap
//

import SwiftUI

struct HomeView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(AvatarManager.self) private var avatar
    @Environment(PartnerManager.self) private var partner
    @Environment(Backend.self) private var backend
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var showRelapse = false
    @State private var showPartner = false
    @State private var showGoalEditor = false
    @State private var showGoalReached = false
    @State private var showSOS = false
    @State private var showSettings = false
    @AppStorage("sosNotifyPartner") private var notifyPartner = false
    @State private var sosPath: [SOSOption] = []
    @State private var newGoalDraft = 21

    /// Три способа переждать тягу — выбор, а не один навязанный сценарий.
    /// .survey — общий финальный шаг для всех трёх, шагом дальше по стеку.
    private enum SOSOption: Hashable {
        case breathing, exercise, motivation, survey
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    greeting
                    summitCard
                        .tourTarget(.homeTimer)
                    quoteCard
                    if !subscriptions.isPro {
                        weeklyReport
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            actions
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .background(Palette.obsidian)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        .confirmationDialog(
            streak.canUseStreakFreeze ? "Как отметить срыв?" : "Защита стрика в этом месяце уже использована",
            isPresented: $showRelapse,
            titleVisibility: .visible
        ) {
            if streak.canUseStreakFreeze {
                Button("Активировать защиту стрика (1 раз в месяц)") {
                    router.freezeDateBeforeShield = streak.activateStreakFreeze()
                    withAnimation { router.selectedTab = AppRouter.diaryTab }
                    router.openRelapseReview = true
                    Task { await backend.pushStreak(from: streak) }
                }
            }
            Button(streak.canUseStreakFreeze ? "Полный сброс стрика до 0" : "Сбросить стрик", role: .destructive) {
                withAnimation(.snappy(duration: 0.4)) {
                    if streak.checkIn(clean: false) {
                        avatar.applyRelapse()
                    }
                }
                Task { await backend.syncRelapse(from: streak) }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(streak.canUseStreakFreeze
                 ? "Твой прогресс сохранится, но тебе необходимо честно разобрать причину срыва в дневнике прямо сейчас."
                 : "Защита стрика в этом месяце уже использована. Стрик будет сброшен.")
        }
        .onChange(of: streak.justReachedGoal) { _, reached in
            if reached {
                newGoalDraft = streak.personalGoalDays
                showGoalReached = true
            }
        }
        .sheet(isPresented: $showPartner) {
            NavigationStack { PartnerView() }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showGoalEditor) {
            VStack(spacing: 24) {
                GoalPicker(selected: $newGoalDraft)
                Button("Сохранить") {
                    streak.setGoal(newGoalDraft)
                    showGoalEditor = false
                }
                .buttonStyle(GoldButton())
            }
            .padding(24)
            .presentationDetents([.height(420)])
            .presentationBackground(Palette.obsidian)
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

                if backend.isOffline {
                    Text("Офлайн-режим")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                        .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Circle()
                    .strokeBorder(Palette.vein, lineWidth: 1)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.marble)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - Стрик

    private var summitCard: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    Image("SisyphusPhoto")
                        .resizable()
                        .scaledToFit()
                        .frame(width: w)

                    VStack(spacing: 0) {
                        ZStack {
                            Text("\(streak.currentStreak)")
                                .font(Face.display(w * 0.14, .semibold))
                                .foregroundStyle(.goldFill)
                                .shadow(color: Palette.goldLight.opacity(0.8), radius: 7)
                                .shadow(color: Palette.gold.opacity(0.5), radius: 13)

                            Text("\(streak.currentStreak)")
                                .font(Face.display(w * 0.14, .semibold))
                                .foregroundStyle(.black.opacity(0.7))
                                .offset(x: w * 0.012, y: w * 0.012 * 1.4)

                            Text("\(streak.currentStreak)")
                                .font(Face.display(w * 0.14, .semibold))
                                .foregroundStyle(.goldFill)
                                .contentTransition(.numericText())
                        }

                        Button {
                            newGoalDraft = streak.personalGoalDays
                            showGoalEditor = true
                        } label: {
                            Text("из \(streak.personalGoalDays) дней")
                                .font(Face.display(w * 0.034))
                                .foregroundStyle(Palette.marbleHigh)
                                .shadow(color: Palette.goldLight.opacity(0.5), radius: 4)
                                .underline()
                        }
                    }
                    .position(x: w * 0.70, y: w * (515.0 / 493.0) * 0.354)
                }
            }
            .aspectRatio(493.0 / 515.0, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 18))
            .cardSurface()
            .overlay(alignment: .bottomLeading) {
                PartnerBadge(width: 130)
                    .contentShape(.rect)
                    .onTapGesture { showPartner = true }
            }

            Text("Лучший стрик: \(streak.bestStreak.daysCount)")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ash)
        }
    }

    private var weeklyReport: some View {
        Button {
            subscriptions.checkProAccess(for: "Разблокируй детальную аналитику срывов и динамику недели") {}
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Еженедельный отчет")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.gold.opacity(0.7))
                            .frame(width: 18, height: CGFloat(24 + index * 8))
                    }
                }
                .blur(radius: subscriptions.isPro ? 0 : 6)
                .frame(maxWidth: .infinity)
                if !subscriptions.isPro {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Доступно в Pro: Аналитика триггеров и график уязвимости")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
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
        // SOS остаётся на экране в любом состоянии: тяга не спрашивает,
        // отмечался ли человек сегодня.
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let remaining = streak.victoryCountdownRemaining(at: context.date) {
                    victoryTimer(remaining)
                } else {
                    Button("Я ДЕРЖУСЬ") {
                        withAnimation(.snappy(duration: 0.25)) {
                            if streak.checkIn(clean: true) {
                                avatar.addPowerForStreak()
                            }
                        }
                    }
                    .buttonStyle(GoldButton())
                    .padding(.top, 6)
                }
            }
            .tourTarget(.homeTimer)

            Button("SOS") { showSOS = true }
                .buttonStyle(SOSButton())
                .tourTarget(.homeSOS)

            Button("Сообщить о срыве") { showRelapse = true }
                .buttonStyle(StoneButton())
        }
    }

    private func victoryTimer(_ remaining: TimeInterval) -> some View {
        VStack(spacing: 8) {
            Text("До ещё одного дня победы над собой осталось:")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(countdownString(remaining))
                .font(Face.display(28, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .cardSurface()
    }

    private func countdownString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - SOS

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

            partnerSOSToggle

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

    private var partnerSOSToggle: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.wave.2.fill")
                .foregroundStyle(Palette.gold)
            Text("Отправить экстренный push напарнику")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.marbleHigh)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if !subscriptions.isPro {
                ProLockBadge()
            }
            Toggle("", isOn: Binding(
                get: { subscriptions.isPro && notifyPartner },
                set: { enabled in
                    if enabled {
                        subscriptions.checkProAccess(for: "Оповещение напарника в моменты риска доступно в тарифе Pro") {
                            notifyPartner = true
                            Task { _ = await partner.send("Мне нужна поддержка: я нажал SOS.", kind: .sos) }
                        }
                    } else {
                        notifyPartner = false
                    }
                }
            ))
            .labelsHidden()
            .tint(Palette.gold)
        }
        .padding(12)
        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sosRow(icon: String, title: LocalizedStringResource, subtitle: LocalizedStringResource, option: SOSOption) -> some View {
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

                Text(verbatim: breathPhase.rawValue)
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
                Text(verbatim: trigger.emoji)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: trigger.title)
                        .font(Face.display(14, .medium))
                        .foregroundStyle(Palette.marbleHigh)
                    Text(verbatim: trigger.subtitle)
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
            Text(verbatim: text).foregroundStyle(Palette.marble)
        }
        .font(.system(size: 14))
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
