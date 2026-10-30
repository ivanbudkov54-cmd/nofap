//
//  KnowledgeView.swift
//  NoFap
//
//  «База знаний» из трёх вкладок: путь по дням стрика, симулятор тяги и
//  статьи по категориям.
//

import SwiftUI

struct KnowledgeView: View {

    private enum Tab: String, CaseIterable, Identifiable, Hashable {
        case journey = "My Journey"
        case simulator = "Urge Simulator"
        case deepDive = "Deep Dive"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .journey:   String(localized: "Мой путь")
            case .simulator: String(localized: "Симулятор тяги")
            case .deepDive:  String(localized: "Статьи")
            }
        }
    }

    @State private var selected: Tab = .journey
    /// Вкладки, которые уже собраны: они остаются в памяти, и переключение
    /// только меняет видимость, ничего не строя заново.
    @State private var visited: Set<Tab> = [.journey]

    /// Выбранный сегмент — золотой, как кнопки приложения. Других
    /// сегментированных переключателей в приложении нет, так что общий
    /// appearance задевает только этот.
    init() {
        let control = UISegmentedControl.appearance()
        control.selectedSegmentTintColor = UIColor(Palette.goldSurface)
        control.setTitleTextAttributes([.foregroundColor: UIColor(Palette.onGold),
                                        .font: UIFont.systemFont(ofSize: 14, weight: .semibold)],
                                       for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor(Palette.marble),
                                        .font: UIFont.systemFont(ofSize: 14, weight: .medium)],
                                       for: .normal)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            content
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // Своя шапка вместо панели навигации — у всех вкладок одна высота.
        .toolbar(.hidden, for: .navigationBar)
        // Остальные вкладки собираем сразу после показа экрана, пока
        // человек читает, — чтобы и первое нажатие не тормозило.
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            visited = Set(Tab.allCases)
        }
        .onChange(of: selected) { _, tab in
            visited.insert(tab)
            Haptics.selection()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Знания")
                .font(Face.display(28, .semibold))
                .foregroundStyle(Palette.marbleHigh)
            Text("Прокачивай разум. Понимай, что происходит на самом деле.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        // Заголовок на 5pt правее карточек — на одной линии с «Привет, воин».
        .padding(.leading, 5)
        .padding(.top, 8)
    }

    /// Системный переключатель: анимацию выделения рисует сама iOS (на
    /// iOS 26 — Liquid Glass), вне SwiftUI-перерисовки. Свой с
    /// matchedGeometryEffect подтормаживал на каждом нажатии.
    private var tabBar: some View {
        Picker("Раздел", selection: $selected) {
            ForEach(Tab.allCases) { tab in
                Text(tab.label).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// Раньше `switch` выбрасывал прошлую вкладку и с нуля собирал новую —
    /// 45 дней пути или все статьи на каждое нажатие, отсюда подтормаживание.
    /// Теперь открытые вкладки лежат стопкой, видна только выбранная.
    private var content: some View {
        ZStack {
            ForEach(Tab.allCases) { tab in
                if visited.contains(tab) {
                    page(tab)
                        .opacity(selected == tab ? 1 : 0)
                        .allowsHitTesting(selected == tab)
                        .accessibilityHidden(selected != tab)
                }
            }
        }
    }

    @ViewBuilder
    private func page(_ tab: Tab) -> some View {
        switch tab {
        case .journey:
            MyJourneyView()
        case .simulator:
            UrgeSimulatorView()
        case .deepDive:
            DeepDiveView()
        }
    }
}
