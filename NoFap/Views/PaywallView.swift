//
//  PaywallView.swift
//  NoFap
//
//  Нейтральный экран доступа Spartan Pro. Покупка в приложении не
//  предлагается: человек входит по email, и приложение только читает статус
//  аккаунта (profiles.is_pro, его пишет оплата на сайте).
//

import SwiftUI

/// Замок на закрытом Pro-контенте.
struct ProLockBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("PRO")
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.onGold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.goldSurface))
        .accessibilityLabel("Доступно в Spartan Pro")
    }
}

struct PaywallView: View {

    /// Функция, на которую нажали: экран начинается с неё. nil — общий
    /// экран Spartan Pro.
    var feature: ProFeature? = nil

    @Environment(PremiumStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var showEmailLink = false
    @State private var openSiteAfterEmail = false
    @State private var isChecking = false
    @State private var statusNote: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: feature == nil ? "что входит" : "ещё в spartan pro")
                        ForEach(ProFeature.allCases.filter { $0 != feature }) { item in
                            benefit(item)
                        }
                    }

                    VStack(spacing: 12) {
                        // Пока Pro бесплатный (freeLaunch), этот экран не
                        // показывается. Перед тем как снова продавать Pro,
                        // кнопку нужно перевести на ExternalPurchaseLink —
                        // без разрешения Apple ссылка на оплату запрещена.
                        Button("Купить Spartan Pro") {
                            Task { await openProgramSite() }
                        }
                        .buttonStyle(GoldButton())

                        if subscriptions.hasLinkedEmail {
                            Button {
                                Task { await refreshStatus() }
                            } label: {
                                if isChecking {
                                    ProgressView()
                                } else {
                                    Text("Уже купил — проверить доступ")
                                }
                            }
                            .buttonStyle(StoneButton())
                            .disabled(isChecking)
                        } else {
                            Button("Уже есть Pro? Войти по Email") {
                                showEmailLink = true
                            }
                            .buttonStyle(StoneButton())
                        }
                    }

                    if let statusNote {
                        Text(statusNote)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.ash)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Spartan Pro привязан к вашему Email: доступ один и тот же на всех устройствах.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(StoneBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Palette.ash)
                }
            }
        }
        .sheet(isPresented: $showEmailLink, onDismiss: {
            guard openSiteAfterEmail else { return }
            openSiteAfterEmail = false
            guard subscriptions.hasLinkedEmail else { return }
            Task { await subscriptions.openExternalWebsite() }
        }) {
            EmailLinkSheet(purpose: .signIn)
        }
        .onChange(of: subscriptions.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
        .presentationDragIndicator(.visible)
        .task { await subscriptions.checkSubscription() }
    }

    private func openProgramSite() async {
        if subscriptions.hasLinkedEmail {
            await subscriptions.openExternalWebsite()
            return
        }
        openSiteAfterEmail = true
        showEmailLink = true
    }

    private func refreshStatus() async {
        isChecking = true
        statusNote = nil
        defer { isChecking = false }
        switch await subscriptions.checkSubscription() {
        case .active:
            statusNote = nil
        case .inactive:
            statusNote = "Активная подписка для данного email не найдена."
        case .unavailable:
            statusNote = "Не удалось обновить статус. Проверьте соединение."
        }
    }

    /// Сначала — что даёт функция, на которую нажали, а не замок.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: feature?.icon ?? "crown.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Palette.onGold)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.goldSurface))

            Eyebrow(text: "spartan pro", color: Palette.gold)

            Text(feature?.title ?? String(localized: "Всё, чтобы держаться дольше"))
                .font(Face.display(26, .semibold))
                .foregroundStyle(Palette.marbleHigh)
                .fixedSize(horizontal: false, vertical: true)

            Text(feature?.summary ?? String(localized: "Аналитика, сквад, аватар и вся база знаний — инструменты, которые помогают заметить срыв до того, как он случится."))
                .font(.system(size: 16))
                .foregroundStyle(Palette.marble)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func benefit(_ item: ProFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.gold)
                .frame(width: 22)
            Text(item.title)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
        }
    }
}
