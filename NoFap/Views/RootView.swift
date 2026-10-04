//
//  RootView.swift
//  NoFap
//
//  Вкладки приложения. Первые четыре — на виду, остальные система прячет
//  в «Ещё». Настройки открываются кружком профиля на главном экране.
//

import SwiftUI

struct RootView: View {

    init() {
        Self.applyTabBar()
    }

    /// Таб-бар берёт те же цвета, что и фон экрана, в обеих темах.
    static func applyTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Palette.tabBar
        appearance.shadowColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x2C2C34) : UIColor(hex: 0xDDDFE5)
        }
        // Системный шрифт таб-бара — засечки в 11pt читаются хуже, чем San Francisco.
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        // Без TabView(selection:): у вкладок в «Ещё» привязка выбранной
        // вкладки сбрасывала навигацию при каждом обновлении данных. Поэтому
        // тур не переключает вкладки сам — показывает подсказки поверх.
        TabView {
            HomeView()
                .tabItem { Label("Главная", systemImage: "house.fill") }

            NavigationStack {
                ChallengesView()
            }
            .tabItem { Label("Челленджи", systemImage: "flag.fill") }

            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Дневник", systemImage: "square.and.pencil") }

            NavigationStack {
                KnowledgeView()
            }
            .tabItem { Label("Знания", systemImage: "text.book.closed.fill") }

            // Временно в «Ещё»: место прогресса на виду заняли челленджи.
            NavigationStack {
                ProgressTabView()
            }
            .tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }

            NavigationStack {
                AvatarScreen()
            }
            .tabItem { Label("Аватар", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack {
                PartnerView()
            }
            .tabItem { Label("Напарник", systemImage: "person.2.fill") }
        }
        .tint(Palette.gold)
        // Всё, что следит за состоянием (приглашения, пейвол, тур,
        // подсказки), — в модификаторах, а не в теле RootView: иначе каждое
        // изменение пересобирало TabView и меню «Ещё» сбрасывало экран.
        .modifier(InviteJoinSheets())
        .modifier(RootOverlays())
    }
}

/// Пейвол по требованию экранов, тур и всплывающие подсказки.
private struct RootOverlays: ViewModifier {

    @Environment(PremiumStore.self) private var premium
    @Environment(AppTourManager.self) private var tour
    @Environment(AppRouter.self) private var router
    @Environment(AvatarProgressManager.self) private var xp
    @Environment(\.colorScheme) private var colorScheme

    @State private var toastVisible = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: TourSpaceName.name)
            .onPreferenceChange(TourFramesKey.self) { tour.setFrames($0) }
            .task { tour.startTourIfNeeded() }
            .sheet(isPresented: Bindable(premium).shouldShowPaywall) {
                PaywallView(contextReason: premium.paywallContextReason)
            }
            // Новый ранг празднуется там, где его заработали: за статьёй,
            // челленджем или «Держусь», а не при следующем заходе в аватар.
            .fullScreenCover(isPresented: Bindable(xp).showLevelUp) {
                SpartanLevelUpView(rank: xp.unlockedRank) { xp.showLevelUp = false }
            }
            .overlay {
                if tour.isTourActive {
                    TourOverlayView().zIndex(999)
                }
            }
            .onChange(of: colorScheme) { _, _ in RootView.applyTabBar() }
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
}
