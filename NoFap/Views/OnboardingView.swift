//
//  OnboardingView.swift
//  NoFap
//
//  Первый запуск: опрос, персональный трек, три тезиса и включение защиты.
//  Дальше пользователь сюда не возвращается — блокировка ставится один раз.
//
//  Порядок страниц описан списком `steps`, а не арифметикой от количества
//  слайдов: раньше индексы считались в трёх местах сразу, и любая вставка
//  экрана требовала править все три.
//

import SwiftUI

struct OnboardingView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(SurveyManager.self) private var survey
    @Environment(ReminderManager.self) private var reminder
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinish: () -> Void

    @State private var page = 0
    @State private var isRequesting = false
    @State private var goalDays = 21

    private enum Step: Hashable {
        case question(Int)
        case track
        case thesis(Int)
        case goal
        case consent
    }

    private static let questionCount = 9

    private let slides: [(title: LocalizedStringResource, body: LocalizedStringResource)] = [
        ("Решение принимается один раз",
         "Приложение блокирует материалы для взрослых во всех браузерах этого iPhone. Не нужно каждый вечер побеждать себя заново — достаточно решить сейчас."),
        ("Не сила воли, а устройство",
         "Фильтр работает на уровне системы, через встроенное Экранное время. Он действует и в Safari, и в других браузерах, и его не обходит приватная вкладка."),
        ("Ничего не уходит без спроса",
         "Ни аккаунта, ни истории посещений. Счётчик и календарь живут только на этом телефоне. Захочешь позвать напарника — он увидит лишь счёт дней и отметился ли ты сегодня. Ни календаря, ни срывов, ни имени.")
    ]

    private var steps: [Step] {
        (0..<Self.questionCount).map(Step.question)
        + [.track]
        + slides.indices.map(Step.thesis)
        + [.goal, .consent]
    }

    var body: some View {
        ZStack {
            StoneBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { index in
                        view(for: steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Свайп пальцем листает в обход кнопки, поэтому неотвеченный
                // вопрос приходится возвращать обратно руками. Возврат —
                // намеренно без анимации: с ней страница уезжала и отскакивала,
                // а полоса прогресса успевала дёрнуться вперёд и вернуться.
                // Это читалось как сбой. Мгновенный возврат читается как
                // «свайп не приняли».
                .onChange(of: page) { previous, current in
                    // Клавиатура и фокус текстового поля не закрывались сами
                    // при перелистывании — TabView просто уносит старую
                    // страницу за экран, а фокус на ней остаётся. Снимаем
                    // фокус явно при любом переходе, вперёд или назад.
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                    guard current > previous, !isAnswered(steps[previous]) else { return }
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { page = previous }
                }

                progress
                    .padding(.bottom, 26)

                footerButton
                    .buttonStyle(EngravedButton())
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Страницы

    @ViewBuilder
    private func view(for step: Step) -> some View {
        switch step {
        case .question(let index): question(index)
        case .track:               trackStep
        case .thesis(let index):   thesis(slides[index])
        case .goal:                goalStep
        case .consent:             consent
        }
    }

    @ViewBuilder
    private func question(_ index: Int) -> some View {
        let number = index + 1
        let total = Self.questionCount

        switch index {
        case 0:
            SurveyQuestionView(index: number, total: total,
                               title: "Как часто случается срыв?",
                               selection: .single(binding(\.frequency)))
        case 1:
            SurveyQuestionView(index: number, total: total,
                               title: "Сколько лет длится эта привычка?",
                               selection: .single(binding(\.years)))
        case 2:
            SurveyQuestionView(index: number, total: total,
                               title: "Что обычно случается прямо перед срывом?",
                               selection: .multiple(binding(\.triggers)))
        case 3:
            SurveyQuestionView(index: number, total: total,
                               title: "Где это обычно происходит?",
                               selection: .multiple(binding(\.settings)),
                               note: binding(\.settingsNote),
                               notePlaceholder: "Например: после смены, когда все уснули")
        case 4:
            SurveyQuestionView(index: number, total: total,
                               title: "В какое время суток тяга накатывает чаще?",
                               selection: .single(binding(\.urgeWindow)))
        case 5:
            SurveyQuestionView(index: number, total: total,
                               title: "Что ты замечаешь за собой сильнее всего?",
                               selection: .multiple(binding(\.effects)),
                               note: binding(\.effectsNote),
                               notePlaceholder: "Например: не могу дочитать страницу")
        case 6:
            SurveyQuestionView(index: number, total: total,
                               title: "Что ты хочешь получить взамен?",
                               selection: .multiple(binding(\.outcomes)))
        case 7:
            SurveyQuestionView(index: number, total: total,
                               title: "Какой самый долгий срок ты продержался?",
                               selection: .single(binding(\.longestStreak)))
        default:
            SurveyQuestionView(index: number, total: total,
                               title: "Кто-нибудь знает о твоей проблеме?",
                               selection: .single(binding(\.whoKnows)))
        }
    }

    private var trackStep: some View {
        PersonalTrackView(answers: survey.answers, track: survey.track)
    }

    private func thesis(_ slide: (title: LocalizedStringResource, body: LocalizedStringResource)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text(slide.title)
                .font(Face.display(34, .medium))
                .foregroundStyle(.marbleFill)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(slide.body)
                .font(.system(size: 16))
                .foregroundStyle(Palette.ash)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }

    private var goalStep: some View {
        GoalPicker(selected: $goalDays)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
    }

    private var consent: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Включим защиту")
                .font(Face.display(34, .medium))
                .foregroundStyle(.marbleFill)

            Text("iOS попросит доступ к Экранному времени. Без него фильтр включить нельзя.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.ash)
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            // Отказ — единственный случай, когда нужны Настройки: сам запрос
            // разрешения iOS показывает прямо здесь, поверх приложения.
            if case .denied = blocking.state {
                VStack(spacing: 12) {
                    Text("Доступ не выдан. Включить его можно в настройках приложения.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.gold)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Открыть настройки") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.goldFill)
                }
                .padding(.top, 18)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    /// Одна и та же кнопка на любом экране, только с разной подписью и
    /// действием на последнем. Раньше кнопка «Включить защиту» была отдельной
    /// и жила внутри `consent`, а общая «ДАЛЕЕ» на этом экране просто
    /// исчезала — из-за этого весь блок под TabView перестраивался и полоса
    /// прогресса прыгала вниз. Общая кнопка всегда занимает одно и то же
    /// место, поэтому прыгать больше нечему.
    @ViewBuilder
    private var footerButton: some View {
        if case .consent = steps[page] {
            Button {
                Task { await enable() }
            } label: {
                if isRequesting {
                    ProgressView().tint(Palette.gold)
                } else {
                    Text("ВКЛЮЧИТЬ ЗАЩИТУ")
                }
            }
            .disabled(isRequesting)
        } else {
            Button("ДАЛЕЕ") { advance() }
                .disabled(!isAnswered(steps[page]))
                .opacity(isAnswered(steps[page]) ? 1 : 0.35)
        }
    }

    /// Четырнадцать точек читались бы как рябь, поэтому полоса: она честно
    /// показывает, сколько пути осталось, не пересчитываясь глазами.
    private var progress: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.vein)

                Capsule()
                    .fill(.goldFill)
                    .frame(width: geometry.size.width * Double(page + 1) / Double(steps.count))
                    // Лёгкое свечение поверх заливки — то самое ощущение
                    // «живой» полосы, а не просто закрашенного прямоугольника.
                    .shadow(color: Palette.gold.opacity(0.6), radius: 4, y: 0)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 28)
        // Без отскока: пружина с затуханием 0.75 давала перелёт, и золотая
        // полоса на миг заявляла прогресс, которого ещё нет. Золото здесь
        // означает заработанное, врать им нельзя.
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.3, extraBounce: 0), value: page)
    }

    // MARK: - Переходы

    /// Ответы пишутся через `update`, чтобы черновик сохранялся на каждом
    /// шаге: закрытое на середине приложение не должно стирать отвеченное.
    private func binding<Value>(_ keyPath: WritableKeyPath<IntroSurveyAnswers, Value>) -> Binding<Value> {
        Binding(
            get: { survey.answers[keyPath: keyPath] },
            set: { value in survey.update { $0[keyPath: keyPath] = value } }
        )
    }

    private func isAnswered(_ step: Step) -> Bool {
        guard case .question(let index) = step else { return true }
        let answers = survey.answers

        return switch index {
        case 0: answers.frequency != nil
        case 1: answers.years != nil
        case 2: !answers.triggers.isEmpty
        case 3: !answers.settings.isEmpty && !answers.settingsNote.isBlank
        case 4: answers.urgeWindow != nil
        case 5: !answers.effects.isEmpty && !answers.effectsNote.isBlank
        case 6: !answers.outcomes.isEmpty
        case 7: answers.longestStreak != nil
        default: answers.whoKnows != nil
        }
    }

    private func advance() {
        switch steps[page] {
        case .question(Self.questionCount - 1):
            survey.complete()
        case .track:
            goalDays = survey.track.recommendedGoalDays
        case .goal:
            streak.setGoal(goalDays)
        default:
            break
        }

        // Явная кривая вместо безымянного withAnimation (он даёт easeInOut
        // ~0.35с). Переход страницы — это движение всего экрана, именно его
        // отключают в режиме уменьшенной анимации.
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.3)) {
            page += 1
        }
    }

    private func enable() async {
        isRequesting = true
        await blocking.enableProtection()
        isRequesting = false

        if blocking.isActive {
            streak.markProtectionStart()
            // Второй системный запрос сразу за первым — обычная практика:
            // человек уже в режиме «выдаю разрешения». Отказ не блокирует
            // выход из онбординга — напоминание просто не ставится.
            if let window = survey.answers.urgeWindow {
                await reminder.enable(peakHour: window.peakHour)
            }
            onFinish()
        }
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
