//
//  SettingsView.swift
//  NoFap
//
//  Настройки в виде группированного списка: сброс стрика, правовые ссылки
//  и удаление аккаунта. Удаление живёт в приложении — Apple Guideline 5.1.1.
//

import SwiftUI
import WebKit

struct SettingsView: View {

    @Environment(CloudSync.self) private var backend
    @Environment(StreakManager.self) private var streak
    @Environment(AvatarManager.self) private var avatar
    @Environment(AvatarProgressManager.self) private var xp
    @Environment(JournalManager.self) private var journal
    @Environment(CheckInManager.self) private var checkIns
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var theme

    @AppStorage("onboardingDone") private var onboardingDone = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedAppTour") private var hasCompletedAppTour = false

    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var failure: String?

    private let supportURL = URL(string: "mailto:support@example.com")!

    var body: some View {
        List {
            Section("Внешний вид") {
                Picker("Тема", selection: Bindable(theme).theme) {
                    ForEach(AppTheme.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: theme.theme) { _, _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }

            Section("Данные и прогресс") {
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
        .scrollContentBackground(.hidden)
        .background(Palette.obsidian.ignoresSafeArea())
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
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
