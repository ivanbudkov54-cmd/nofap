//
//  RootView.swift
//  NoFap
//
//  Пять вкладок из макета. Готова только «Главная» — остальные показывают
//  честную заглушку вместо пустого экрана.
//

import SwiftUI

struct RootView: View {

    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AppTourManager.self) private var tour
    @Environment(\.colorScheme) private var colorScheme
    @State private var toastVisible = false

    init() {
        Self.applyTabBar()
    }

    /// Таб-бар берёт те же динамические цвета, что и фон экрана.
    private static func applyTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Palette.tabBar
        appearance.shadowColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: 0x2C2C34)
                : UIColor(hex: 0xDDDFE5)
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: Bindable(router).selectedTab) {
            HomeView()
                .tabItem { Label("Главная", systemImage: "house.fill") }
                .tag(0)

            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Дневник", systemImage: "square.and.pencil") }
            .tag(AppRouter.diaryTab)

            NavigationStack {
                KnowledgeView()
            }
            .tabItem { Label("Знания", systemImage: "text.book.closed.fill") }
            .tag(2)

            NavigationStack {
                ChallengesView()
            }
            .tabItem { Label("Челленджи", systemImage: "flag.fill") }
            .tag(3)

            NavigationStack {
                AvatarView()
            }
            .tabItem { Label("Аватар", systemImage: "figure.strengthtraining.traditional") }
            .tag(5)
        }
        .tint(Palette.gold)
        .coordinateSpace(name: TourSpaceName.name)
        .onPreferenceChange(TourFramesKey.self) { tour.setFrames($0) }
        .task { tour.startTourIfNeeded() }
        .sheet(isPresented: Bindable(subscriptions).shouldShowPaywall) {
            PaywallView(contextReason: subscriptions.paywallContextReason)
        }
        .onChange(of: tour.currentStepIndex) { _, _ in
            focusTourTab()
        }
        .onChange(of: tour.isTourActive) { _, active in
            if active { focusTourTab() }
        }
        .overlay {
            if tour.isTourActive {
                TourOverlayView()
                    .zIndex(999)
            }
        }
        .onChange(of: colorScheme) { _, _ in
            Self.applyTabBar()
        }
        .overlay(alignment: .top) {
            if toastVisible, let toast = router.toast {
                Text(toast)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: 0x1A1405))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.goldFill))
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: router.toast) { _, toast in
            guard toast != nil else { return }
            withAnimation { toastVisible = true }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation { toastVisible = false }
                router.toast = nil
            }
        }
    }

    private func focusTourTab() {
        guard tour.isTourActive, let tag = tour.step.tab else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            router.selectedTab = tag
        }
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
