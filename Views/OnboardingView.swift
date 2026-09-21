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

    let onFinish: () -> Void

    @State private var page = 0
    @State private var isRequesting = false
    @State private var goalDays = 21

    private let slides: [(mark: String, title: String, body: String)] = [
        ("I",
         "Решение принимается один раз",
         "Приложение блокирует материалы для взрослых во всех браузерах этого iPhone. Не нужно каждый вечер побеждать себя заново — достаточно решить сейчас."),
        ("II",
         "Не сила воли, а устройство",
         "Фильтр работает на уровне системы, через встроенное Экранное время. Он действует и в Safari, и в других браузерах, и его не обходит приватная вкладка."),
        ("III",
         "Мы о тебе ничего не знаем",
         "Ни аккаунта, ни сервера, ни истории посещений. Счётчик дней хранится только на этом телефоне. Мы физически не можем увидеть твои данные.")
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

    private func thesis(_ slide: (mark: String, title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Римская цифра — номер тезиса, а не украшение: слайдов ровно три.
            Text(slide.mark)
                .font(Face.display(15, .medium))
                .tracking(3)
                .foregroundStyle(.goldFill)

            Rectangle()
                .fill(Palette.gold.opacity(0.4))
                .frame(width: 26, height: 1)
                .padding(.top, 12)

            Text(slide.title)
                .font(Face.display(34, .medium))
                .foregroundStyle(.marbleFill)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

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

            if case .denied = blocking.state {
                Text("Доступ не выдан. Его можно открыть в Настройках → Экранное время.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.gold)
                    .multilineTextAlignment(.center)
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

    /// Засечки вместо точек — тот же язык, что у дуги стрика.
    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0...(slides.count + 1), id: \.self) { i in
                Capsule()
                    .fill(i == page ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein))
                    .frame(width: i == page ? 18 : 6, height: 2)
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
