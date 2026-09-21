//
//  RootView.swift
//  NoFap
//
//  Пять вкладок из макета. Готова только «Главная» — остальные показывают
//  честную заглушку вместо пустого экрана.
//

import SwiftUI

struct RootView: View {

    init() {
        // Таб-бар остаётся тёмным даже при прокрутке контента под него.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Palette.obsidian)
        appearance.shadowColor = UIColor(Palette.vein)
        // Системный шрифт таб-бара — засечки в 11pt читаются хуже, чем San Francisco.
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Главная", systemImage: "house.fill") }

            NavigationStack {
                ProgressTabView()
            }
            .tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }

            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Дневник", systemImage: "square.and.pencil") }

            NavigationStack {
                KnowledgeView()
            }
            .tabItem { Label("Знания", systemImage: "text.book.closed.fill") }

            NavigationStack {
                PartnerView()
            }
            .tabItem { Label("Напарник", systemImage: "person.2.fill") }

            Soon(title: "Профиль", note: "Настройки защиты, напоминания и удаление данных.")
                .tabItem { Label("Профиль", systemImage: "person.fill") }
        }
        .tint(Palette.gold)
    }
}

private struct Soon: View {
    let title: LocalizedStringResource
    let note: LocalizedStringResource

    var body: some View {
        ZStack {
            Palette.obsidian.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .font(Face.display(30, .medium))
                    .foregroundStyle(.marbleFill)

                Text(note)
                    .font(Face.display(16))
                    .foregroundStyle(Palette.ash)
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Eyebrow(text: "в разработке", color: Palette.gold)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 40)
        }
    }
}
