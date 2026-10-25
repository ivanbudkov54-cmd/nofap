//
//  SettingsView.swift
//  NoFap
//
//  Настройки в виде группированного списка: сброс стрика, правовые ссылки
//  и удаление аккаунта. Удаление живёт в приложении — Apple Guideline 5.1.1.
//

import SwiftUI
import WebKit
import FamilyControls

struct SettingsView: View {

    @Environment(CloudSync.self) private var backend
    @Environment(StreakManager.self) private var streak
    @Environment(AvatarManager.self) private var avatar
    @Environment(AvatarProgressManager.self) private var xp
    @Environment(JournalManager.self) private var journal
    @Environment(CheckInManager.self) private var checkIns
    @Environment(ThemeManager.self) private var themes
    @Environment(PremiumStore.self) private var subscriptions
    @Environment(BlockingManager.self) private var blocking
    @Environment(\.openURL) private var openURL

    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppTourManager.seenKey) private var hasCompletedAppTour = false

    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var failure: String?
    @State private var showEmailLink = false
    @State private var showTriggerPicker = false
    @State private var triggerDraft = FamilyActivitySelection()

    private let supportURL = AppInfo.supportURL

    var body: some View {
        List {
            Section {
                if let email = subscriptions.accountEmail, !email.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email привязан")
                            .foregroundStyle(Palette.marbleHigh)
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ash)
                    }
                } else {
                    Button {
                        showEmailLink = true
                    } label: {
                        HStack {
                            Text("Привязать Email / Резервная копия")
                                .foregroundStyle(Palette.marbleHigh)
                            Spacer()
                            Image(systemName: "envelope")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ash)
                        }
                    }
                }
            }

            protectionSection

            Section("Управление подпиской") {
                NavigationLink {
                    SubscriptionStatusView()
                } label: {
                    Text("Управление подпиской").foregroundStyle(Palette.marbleHigh)
                }
            }

            Section {
                NavigationLink {
                    PartnerView()
                } label: {
                    Label { Text("Напарник и сквад").foregroundStyle(Palette.marbleHigh) } icon: { Image(systemName: "person.2.fill").foregroundStyle(Palette.gold) }
                }
                NavigationLink {
                    ProgressTabView()
                } label: {
                    Label { Text("Прогресс").foregroundStyle(Palette.marbleHigh) } icon: { Image(systemName: "chart.bar.fill").foregroundStyle(Palette.gold) }
                }
            }

            Section("Оформление") {
                Picker(selection: Binding(get: { themes.theme }, set: { themes.theme = $0 })) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.title, systemImage: theme.symbol).tag(theme)
                    }
                } label: {
                    Label { Text("Тема").foregroundStyle(Palette.marbleHigh) } icon: {
                        Image(systemName: "circle.lefthalf.filled").foregroundStyle(Palette.gold)
                    }
                }
                .tint(Palette.gold)
            }

            Section("Данные") {
                Button("Сбросить текущий стрик") {
                    confirmReset = true
                }
                .foregroundStyle(Palette.marbleHigh)
            }

            Section("Правовая информация и поддержка") {
                NavigationLink("Политика конфиденциальности") {
                    SettingsView.LegalDocumentView(title: "Политика конфиденциальности", resource: "privacy")
                }
                NavigationLink("Условия использования") {
                    SettingsView.LegalDocumentView(title: "Условия использования", resource: "terms")
                }
                linkRow("Apple Standard EULA", url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                linkRow("Служба поддержки", url: supportURL)
            }

            Section {
                Button("Удалить аккаунт и данные", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(isDeleting || !SupabaseConfig.isConfigured)
            } footer: {
                Text("Удаление стирает историю воздержания, дневник и сессию на этом устройстве и на сервере.")
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Palette.obsidian.ignoresSafeArea())
        .sheet(isPresented: $showEmailLink) { EmailLinkSheet(purpose: .backup) }
        .familyActivityPicker(isPresented: $showTriggerPicker, selection: $triggerDraft)
        .onChange(of: triggerDraft) { _, selection in
            Task { await blocking.setTriggers(selection) }
        }
        .navigationTitle("Настройки")
        // Компактный заголовок — без пустой полосы над списком.
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Сбросить текущий стрик?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Сбросить", role: .destructive) {
                withAnimation {
                    if streak.checkIn(clean: false) {
                        avatar.applyRelapse()
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Текущий счётчик обнулится. Рекорд сохранится, если он был больше.")
        }
        .confirmationDialog(
            "Удалить аккаунт и данные?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Удалить всё", role: .destructive) {
                Task { await removeAccount() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие безвозвратно удалит вашу историю воздержания, заметки в дневнике и все персональные данные. Продолжить?")
        }
        .alert("Не удалось удалить аккаунт", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("Повторить") { Task { await removeAccount() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView("Удаление…")
                        .padding(24)
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
                .allowsHitTesting(true)
            }
        }
    }

    /// Фильтр 18+ и щит на приложения-триггеры.
    private var protectionSection: some View {
        Section {
            if blocking.isActive {
                Label {
                    Text("Фильтр сайтов 18+ включён").foregroundStyle(Palette.marbleHigh)
                } icon: {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(Palette.gold)
                }

                Button {
                    triggerDraft = blocking.triggers
                    showTriggerPicker = true
                } label: {
                    HStack {
                        Text("Сайты-триггеры").foregroundStyle(Palette.marbleHigh)
                        Spacer()
                        Text(blocking.triggerCount > 0 ? "\(blocking.triggerCount)" : "Выбрать")
                            .foregroundStyle(Palette.ash)
                    }
                }

                if blocking.stops > 0 {
                    HStack {
                        Text("Остановок на щите").foregroundStyle(Palette.marbleHigh)
                        Spacer()
                        Text("\(blocking.stops)").foregroundStyle(Palette.gold)
                    }
                }
            } else if case .denied = blocking.state {
                Text("Доступ к Экранному времени не выдан.")
                    .foregroundStyle(Palette.ash)
                linkRow("Открыть настройки iOS", url: URL(string: UIApplication.openSettingsURLString)!)
            } else {
                Button("Включить защиту") {
                    Task { await blocking.enableProtection() }
                }
                .foregroundStyle(Palette.gold)
            }
        } header: {
            Text("Защита")
        } footer: {
            Text(blocking.isActive
                 ? "Выбери сайты, с которых обычно начинается срыв, — вместо них откроется экран со стриком и кнопкой SOS. В списке есть сайты, которые ты открывал в Safari. Приложения не блокируются, даже если отметить их: чаты остаются."
                 : "Фильтр Apple закрывает сайты 18+ во всех браузерах этого iPhone. Нужен доступ к Экранному времени.")
        }
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Palette.marbleHigh)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ash)
            }
        }
    }

struct LegalDocumentView: View {
    let title: String
    let resource: String

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: resource, withExtension: "html")
                ?? Bundle.main.url(forResource: resource, withExtension: "html", subdirectory: "Legal")
                ?? Bundle.main.url(forResource: resource, withExtension: "html", subdirectory: "Resources/Legal") {
                LegalWebView(url: url)
            } else {
                ContentUnavailableView("Документ не найден", systemImage: "doc")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.white.ignoresSafeArea())
    }
}

private struct LegalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

    private func removeAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await backend.deleteAccount(streak: streak, journal: journal, checkIns: checkIns)
            avatar.resetAll()
            xp.resetAll()
            onboardingDone = false
            hasCompletedOnboarding = false
            hasCompletedAppTour = false
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
