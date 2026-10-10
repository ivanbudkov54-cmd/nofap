//
//  KnowledgeView.swift
//  NoFap
//
//  «База знаний» из трёх вкладок: путь по дням стрика, симулятор тяги и
//  статьи по категориям.
//

import SwiftUI

struct KnowledgeView: View {

    private enum Tab: String, CaseIterable, Identifiable {
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
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selected == tab
        return Button {
            withAnimation(.snappy(duration: 0.25)) { selected = tab }
        } label: {
            Text(tab.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color(hex: 0x1A1405) : Palette.ash)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.goldFill)
                            .matchedGeometryEffect(id: "knowledgeTabHighlight", in: tabAnimation)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch selected {
        case .journey:
            MyJourneyView()
        case .simulator:
            UrgeSimulatorView()
        case .deepDive:
            DeepDiveView()
        }
    }
}
