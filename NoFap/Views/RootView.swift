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
            traits.userInterfaceStyle == .dark ? UIColor(hex: 0x2C2C34) : UIColor(hex: 0xE4DED2)
        }
        // Системный шрифт таб-бара — засечки в 11pt читаются хуже, чем San Francisco.
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Выбранная вкладка живёт здесь, а не в AppRouter: так её смена не
    /// пересобирает остальные экраны. Меню «Ещё» нет — вкладок ровно пять,
    /// поэтому привязка больше не сбрасывает навигацию, как раньше. Тур
    /// вкладки по-прежнему не переключает — показывает подсказки поверх.
    @State private var tab = AppRouter.homeTab

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Главная", systemImage: "house.fill") }
                .tag(AppRouter.homeTab)

            NavigationStack {
                ChallengesView()
            }
            .tabItem { Label("Челленджи", systemImage: "flag.fill") }
            .tag(1)

            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Дневник", systemImage: "square.and.pencil") }
            .tag(AppRouter.diaryTab)

            NavigationStack {
                KnowledgeView()
            }
            .tabItem { Label("Знания", systemImage: "text.book.closed.fill") }
            .tag(AppRouter.knowledgeTab)

            NavigationStack {
                AvatarScreen()
            }
            .tabItem { Label("Аватар", systemImage: "figure.strengthtraining.traditional") }
            .tag(4)
        }
        .tint(Palette.gold)
        // Нажатие на напоминание открывает его вкладку; SOS — главную,
        // там его покажет HomeView.
        .onAppear(perform: openRequestedTab)
        .onChange(of: OpenRequest.shared.destination) { _, _ in openRequestedTab() }
        .onChange(of: OpenRequest.shared.sos) { _, requested in
            if requested { tab = AppRouter.homeTab }
        }
        // Всё, что следит за состоянием (приглашения, пейвол, тур,
        // подсказки), — в модификаторах, а не в теле RootView: иначе каждое
        // изменение пересобирало TabView и меню «Ещё» сбрасывало экран.
        .modifier(InviteJoinSheets())
        .modifier(RootOverlays())
    }

    private func openRequestedTab() {
        guard let destination = OpenRequest.shared.destination else { return }
        OpenRequest.shared.destination = nil
        switch destination {
        case .home: tab = AppRouter.homeTab
        case .diary: tab = AppRouter.diaryTab
        case .knowledge: tab = AppRouter.knowledgeTab
        case .checkIn:
            tab = AppRouter.diaryTab
            OpenRequest.shared.checkIn = true
        }
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
            .onPreferenceChange(TourPulseKey.self) { tour.setPulseFrame($0) }
            .task { await tour.startTourIfNeeded() }
            .sheet(isPresented: Bindable(premium).shouldShowPaywall) {
                PaywallView(contextReason: premium.paywallContextReason)
            }
            // Новый ранг празднуется там, где его заработали: за статьёй,
            // челленджем или «Держусь», а не при следующем заходе в аватар.
            // Карточка награды — над таб-баром, после каждого начисления опыта.
            .overlay(alignment: .bottom) {
                if let gain = xp.lastGain {
                    XPGainToast(gain: gain) { xp.finishGain() }
                        .id(gain.id)
                        .padding(.bottom, 96)
                }
            }
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
                        .foregroundStyle(Palette.onGold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.goldSurface))
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
