//
//  OnboardingView.swift
//  NoFap
//
//  Первый запуск: три тезиса и включение защиты. Дальше пользователь
//  сюда не возвращается — блокировка ставится один раз.
//

import SwiftUI

struct OnboardingView: View {

    @Environment(BlockingManager.self) private var blocking
    @Environment(StreakManager.self) private var streak
    @Environment(\.openURL) private var openURL

    let onFinish: () -> Void

    @State private var page = 0
    @State private var isRequesting = false
    @State private var goalDays = 21

    private let slides: [(title: String, body: String)] = [
        ("Решение принимается один раз",
         "Приложение блокирует материалы для взрослых во всех браузерах этого iPhone. Не нужно каждый вечер побеждать себя заново — достаточно решить сейчас."),
        ("Не сила воли, а устройство",
         "Фильтр работает на уровне системы, через встроенное Экранное время. Он действует и в Safari, и в других браузерах, и его не обходит приватная вкладка."),
        ("Ничего не уходит без спроса",
         "Ни аккаунта, ни истории посещений. Счётчик и календарь живут только на этом телефоне. Захочешь позвать напарника — он увидит лишь счёт дней и отметился ли ты сегодня. Ни календаря, ни срывов, ни имени.")
    ]

    var body: some View {
        ZStack {
            StoneBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        thesis(slide)
                            .tag(index)
                    }
                    goalStep.tag(slides.count)
                    consent.tag(slides.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                progress
                    .padding(.bottom, 26)

                if page < slides.count + 1 {
                    Button("ДАЛЕЕ") {
                        if page == slides.count { streak.setGoal(goalDays) }
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(EngravedButton())
                    .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func thesis(_ slide: (title: String, body: String)) -> some View {
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
        VStack {
            Spacer()
            GoalPicker(selected: $goalDays)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
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

            Button {
                Task { await enable() }
            } label: {
                if isRequesting {
                    ProgressView().tint(Palette.gold)
                } else {
                    Text("ВКЛЮЧИТЬ ЗАЩИТУ")
                }
            }
            .buttonStyle(EngravedButton())
            .disabled(isRequesting)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    /// Привычные точки, как в системных экранах iOS: тонкие засечки на
    /// тёмном фоне почти не читались.
    private var progress: some View {
        HStack(spacing: 9) {
            ForEach(0...(slides.count + 1), id: \.self) { i in
                Circle()
                    .fill(i == page ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein))
                    .frame(width: 8, height: 8)
                    .animation(.snappy, value: page)
            }
        }
    }

    private func enable() async {
        isRequesting = true
        await blocking.enableProtection()
        isRequesting = false

        if blocking.isActive {
            streak.markProtectionStart()
            onFinish()
        }
    }
}
