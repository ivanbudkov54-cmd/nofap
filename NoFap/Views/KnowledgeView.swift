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
    /// Вкладки, которые уже открывали: они остаются в памяти, и повторное
    /// переключение не строит списки заново.
    @State private var visited: Set<Tab> = [.journey]
    @Namespace private var tabAnimation

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            content
        }
        .background(Palette.obsidian.ignoresSafeArea())
        // Своя шапка вместо панели навигации — у всех вкладок одна высота.
        .toolbar(.hidden, for: .navigationBar)
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

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(Palette.basalt, in: .capsule)
        .overlay { Capsule().strokeBorder(Palette.vein, lineWidth: 1) }
        // Анимируется только подсветка. Раньше в анимацию попадала и смена
        // вкладки целиком: три длинных списка перестраивались внутри одной
        // транзакции, и переключение подтормаживало.
        .animation(.snappy(duration: 0.25), value: selected)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selected == tab
        return Button {
            Haptics.selection()
            visited.insert(tab)
            selected = tab
        } label: {
            Text(tab.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Palette.onGold : Palette.ash)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.goldSurface)
                            .matchedGeometryEffect(id: "knowledgeTabHighlight", in: tabAnimation)
                    }
                }
        }
        .buttonStyle(.plain)
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
