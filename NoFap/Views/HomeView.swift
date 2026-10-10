//
//  HomeView.swift
//  NoFap
//

import SwiftUI

struct HomeView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(PartnerManager.self) private var partner
    @Environment(ReasonsStore.self) private var reasons
    @Environment(AvatarManager.self) private var avatar
    @Environment(AvatarProgressManager.self) private var xp

    @State private var showRelapse = false
    @State private var showShieldReview = false
    @State private var showSettings = false
    @State private var showGoalReached = false
    @State private var newGoalDraft = 21

    @State private var showSOS = false
    @State private var sosPath: [SOSOption] = []

    /// Три способа переждать тягу — выбор, а не один навязанный сценарий.
    /// .survey — общий финальный шаг для всех трёх, шагом дальше по стеку.
    private enum SOSOption: Hashable {
        case breathing, exercise, motivation, survey
        /// Сигнал напарнику уже ушёл — открыт чат, чтобы видеть ответ.
        case partner
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                greeting
                // Сизиф с валуном — и стрик, и цель, и напарник со сквадом
                // в одной картинке. Заменил «Твой стрик» и «Свободен от».
                SisyphusStreakCard()
                    .tourTarget(.homeTimer)
                    .padding(.top, 8)
                quoteCard
                actions
            }
            .padding(.horizontal, 15)
            // Запас снизу небольшой: нижние 12pt зоны нажатия «Сообщить о
            // срыве» сами работают буфером перед таб-баром.
            .padding(.bottom, 12)
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // .alert вместо .confirmationDialog: в iOS 26 у confirmationDialog
        // появилась стрелка-«хвостик», указывающая на кнопку-источник — на
        // телефоне она смотрится бессмысленно, ни на что осмысленное не
        // указывая. alert всегда по центру экрана, без этой стрелки.
        .alert(
            "Сорвался?",
            isPresented: $showRelapse
        ) {
            // Обнуление — деликатный момент, поэтому медленнее отметки: число
            // должно осесть, а не щёлкнуть.
            // Щит — раз в месяц и только до обнуления: после сброса
            // сохранять уже нечего.
            if canShieldToday {
                Button("Сохранить стрик щитом") { showShieldReview = true }
            }
            Button(canShieldToday ? "Сбросить стрик" : "Сорвался", role: .destructive) {
                RelapseLog.record()
                withAnimation(.snappy(duration: 0.4)) {
                    if streak.checkIn(clean: false) { avatar.applyRelapse() }
                }
            }
            // .alert не добавляет «Отмена» сам, в отличие от confirmationDialog —
            // прописываем явно, иначе закрыть можно только отметив срыв.
            Button("Отмена", role: .cancel) {}
        } message: {
            // Текст зависит от того, есть ли напарник: обещать «никуда не
            // отправляется», когда счёт видит другой человек, — враньё.
            Text(relapseNote)
        }
        .sheet(isPresented: $showShieldReview) { ShieldReflectionView() }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
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
            .fittedSheet()
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
                        case .partner:    PartnerChatView()
                        }
                    }
            }
            // С напарником в меню четыре пути — окну нужно чуть больше места.
            .presentationDetents([.height(partner.isPaired ? 650 : 560), .large])
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
                .foregroundStyle(Palette.garnet)
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
                // Тот же сигнал «Мне сейчас трудно», что и в чате, — но
                // одним нажатием отсюда: до кнопки в чате в момент тяги
                // никто не дойдёт. Бесплатно, как всё для момента тяги.
                if partner.isPaired {
                    sosRow(icon: "person.wave.2.fill", title: "Сигнал напарнику",
                           subtitle: "«\(ChatPresets.sos)» одним нажатием", option: .partner) {
                        Task { _ = await partner.send(ChatPresets.sos, kind: .sos) }
                    }
                }
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

    private func sosRow(icon: String, title: LocalizedStringResource, subtitle: LocalizedStringResource,
                        option: SOSOption, onSelect: (() -> Void)? = nil) -> some View {
        Button {
            onSelect?()
            sosPath.append(option)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.garnet)
                    .frame(width: 40, height: 40)
                    .background(Palette.garnet.opacity(0.12), in: .circle)

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
        case inhale, hold, exhale

        var label: LocalizedStringResource {
            switch self {
            case .inhale: "Вдох"
            case .hold:   "Задержи"
            case .exhale: "Выдох"
            }
        }
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
                    .fill(Palette.garnet.opacity(0.12))
                    .frame(width: 180, height: 180)

                Circle()
                    .strokeBorder(Palette.garnet.opacity(0.6), lineWidth: 1.6)
                    .frame(width: 150, height: 150)
                    .scaleEffect(breathScale)

                Text(breathPhase.label)
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
                .foregroundStyle(Palette.garnet)
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

    /// Свои причины из WhyView — те же самые, что человек уже отметил себе.
    /// Встроенные причины хранятся по своему заголовку (см. ReasonsStore),
    /// поэтому нужный текст — либо сам ключ, либо текст своей причины.
    private var selectedReasonTexts: [String] {
        reasons.selected.map { key in
            reasons.custom.first(where: { $0.key == key })?.text ?? key
        }
    }

    private var motivationView: some View {
        VStack(spacing: 22) {
            Image(systemName: "quote.opening")
                .font(.system(size: 32))
                .foregroundStyle(Palette.garnet)
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

            if !selectedReasonTexts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(selectedReasonTexts, id: \.self) { bulletTip(verbatim: $0) }
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

    private func bulletTip(verbatim text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("—").foregroundStyle(Palette.garnet)
            Text(verbatim: text).foregroundStyle(Palette.marble)
        }
        .font(.system(size: 14))
    }

    private func bulletTip(_ text: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("—").foregroundStyle(Palette.garnet)
            Text(text).foregroundStyle(Palette.marble)
        }
        .font(.system(size: 14))
    }

    /// Тернарник из строковых литералов Swift выводит как `String`, и такой
    /// текст не попадает в каталог локализации. Явный тип это чинит.
    private var canShieldToday: Bool {
        streak.canUseShield && streak.status(on: Date()) != false
    }

    private var relapseNote: LocalizedStringResource {
        // Отметка уходит и в личную копию на сервере, но видна только самому
        // человеку — обещать «никуда не отправляется» уже было бы неправдой.
        let reset: LocalizedStringResource = partner.isPaired
            ? "Сброс: счётчик обнулится, рекорд останется. Напарник увидит, что счёт начался заново, но не узнает причину."
            : "Сброс: счётчик обнулится, рекорд останется. Отметку видишь только ты."
        guard canShieldToday else { return reset }
        return partner.isPaired
            ? "Щит сохранит стрик, если сразу честно разобрать срыв в дневнике. Он даётся раз в месяц. Без щита счётчик обнулится, рекорд останется. Напарник увидит, что счёт начался заново, но не узнает причину."
            : "Щит сохранит стрик, если сразу честно разобрать срыв в дневнике. Он даётся раз в месяц. Без щита счётчик обнулится, рекорд останется. Отметку видишь только ты."
    }

    private var greetingNote: LocalizedStringResource {
        blocking.isActive ? "Защита стоит. Ты здесь, чтобы стать лучше." : "Ты здесь, чтобы стать лучше."
    }

    // MARK: - Шапка

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Привет, воин")
                    .font(Face.display(24, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(greetingNote)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ash)
            }

            Spacer()

            Button { showSettings = true } label: {
                Circle()
                    .strokeBorder(Palette.vein, lineWidth: 1)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.marble)
                    }
                    // Зона нажатия больше самого кружка — 44pt по HIG.
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Настройки")
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
            // Цитата ближе к картинке, а кнопки под ней остаются на месте:
            // сверху отступ меньше, снизу — больше.
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Действия

    /// Три круга в ряд — та же форма, что у знаков «свободы дня» выше, чтобы
    /// низ экрана читался как продолжение той же системы, а не как чужая
    /// панель. «Держусь» — по центру и крупнее: это главное действие экрана,
    /// глаз должен падать на него первым, а не бежать слева направо по ряду.
    private var actions: some View {
        HStack(alignment: .top, spacing: 18) {
            // Контур вместо заливки: чёрная сердцевина, красный ободок и
            // такая же красная рука — холоднее и тревожнее сплошного гранта,
            // ближе к предупреждающему знаку, чем к обычной кнопке.
            circleAction(icon: "hand.raised.fill", title: "SOS",
                         tint: Palette.garnet, filled: false, boldOutline: true) { showSOS = true }
                .tourTarget(.homeSOS)

            if streak.hasCheckedInToday {
                // Вместо галочки — сколько осталось до новой отметки.
                NextCheckInCountdown(size: 92)
            } else {
                // Без транзакции `.contentTransition(.numericText())` на числе
                // стрика не срабатывает — число просто перещёлкивалось. Это
                // главный момент награды в приложении, он должен перекатиться.
                circleAction(icon: "FlameIcon", custom: true, title: "Держусь",
                             tint: Palette.gold, filled: true, size: 92, glow: true) {
                    withAnimation(.snappy(duration: 0.25)) {
                        if streak.checkIn(clean: true) {
                            avatar.addPowerForStreak()
                            xp.rewardStreakDay(streak.currentStreak)
                        }
                    }
                }
            }

            circleAction(icon: "exclamationmark.triangle", title: "Срыв",
                         tint: Palette.ash, filled: false) { showRelapse = true }
        }
        .frame(maxWidth: .infinity)
    }

    /// `action == nil` — круг остаётся как индикатор состояния, а не кнопка.
    /// `boldOutline` — контурный вариант без размытия заливки: чёрная
    /// сердцевина и цвет на полную силу, а не приглушённый (как у «Срыв»).
    /// `glow` — мягкое пятно света позади круга, тише, чем было в прошлый
    /// раз: обозначить главное действие, а не забить светом всё вокруг.
    private func circleAction(
        icon: String,
        custom: Bool = false,
        title: LocalizedStringResource,
        tint: Color,
        filled: Bool,
        boldOutline: Bool = false,
        size: CGFloat = 84,
        glow: Bool = false,
        action: (() -> Void)?
    ) -> some View {
        return Button {
            action?()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    if glow {
                        Circle()
                            .fill(tint)
                            .frame(width: size * 1.15, height: size * 1.15)
                            .blur(radius: 16)
                            .opacity(0.3)
                    }

                    if filled {
                        Circle().fill(tint.opacity(0.94))
                            .shadow(color: tint.opacity(0.3), radius: 14, y: 4)
                    } else if boldOutline {
                        Circle().fill(Palette.obsidian)
                            .overlay { Circle().strokeBorder(tint, lineWidth: 2) }
                    } else {
                        Circle().fill(tint.opacity(0.08))
                            .overlay { Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5) }
                    }

                    Group {
                        if custom {
                            // Своя иконка — шаблон, красится как системная.
                            Image(icon)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(height: size * 0.4)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: size * 0.33, weight: .medium))
                        }
                    }
                        // На залитом круге иконка «вырезана» фоном экрана,
                        // на пустом — светится самим цветом круга.
                        .foregroundStyle(filled ? Color(hex: 0x1A1405) : tint)
                }
                .frame(width: size, height: size)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(filled ? Palette.marbleHigh : Palette.ash)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

}

// MARK: - Общие элементы

extension View {
    /// Поверхность карточки: чуть светлее фона плюс тонкая граница.
    /// Лист ровно по высоте содержимого: поднимается снизу настолько,
    /// насколько нужно, без пустоты внизу. Одинаково для всех таких листов.
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }

    func cardSurface() -> some View {
        background(Palette.basalt, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.vein, lineWidth: 1)
            }
    }
}

/// Главное действие — единственная сплошная золотая заливка в приложении.
struct GoldButton: ButtonStyle {
    /// Приподжатая высота для компактных экранов (см. `HomeView.compact`) —
    /// остальные вызовы (`GoldButton()`) остаются прежнего размера.
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color(hex: 0x1A1405))
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 46 : 50)
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
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 44 : 50)
            .background(Capsule().fill(Palette.garnet.opacity(configuration.isPressed ? 0.8 : 0.94)))
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

// MARK: - До новой отметки

/// Круг «Отмечено» с обратным отсчётом до полуночи: тогда «Держусь» снова
/// станет доступно. Тот же вид, что у контурных кнопок рядом.
private struct NextCheckInCountdown: View {

    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Self.untilMidnight(from: context.date)

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Palette.gold.opacity(0.08))
                        .overlay { Circle().strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1.5) }

                    VStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: size * 0.16, weight: .semibold))
                        Text(Self.clock(remaining))
                            .font(.system(size: size * 0.19, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .foregroundStyle(Palette.gold)
                }
                .frame(width: size, height: size)

                Text("до нового дня")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ash)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Сегодня отмечено. Следующая отметка через \(Self.spoken(remaining))"))
        }
    }

    private static func untilMidnight(from now: Date) -> TimeInterval {
        let calendar = Calendar.autoupdatingCurrent
        let next = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                     matchingPolicy: .nextTime) ?? now
        return max(0, next.timeIntervalSince(now))
    }

    private static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    private static func spoken(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .full
        return formatter.string(from: interval) ?? ""
    }
}

private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 320

    func body(content: Content) -> some View {
        content
            .padding(.bottom, 12)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.obsidian)
    }
}
