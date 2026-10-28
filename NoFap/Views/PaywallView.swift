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

    var contextReason: String? = nil

    @Environment(PremiumStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var showEmailLink = false
    @State private var isChecking = false
    @State private var statusNote: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.goldFill)

                    Text("Функция программы Spartan Pro")
                        .font(Face.display(26, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                        .fixedSize(horizontal: false, vertical: true)

                    if let contextReason, !contextReason.isEmpty {
                        Text(contextReason)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ash)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        benefit("Экспресс-чекин")
                        benefit("Аналитика триггеров")
                        benefit("Аватар прогресса")
                        benefit("Сквад: группа до четырёх человек")
                        benefit("Расширенная база знаний")
                    }

                    if subscriptions.hasLinkedEmail {
                        Text("Для этого аккаунта Pro-доступ ещё не активирован.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.marble)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Task { await refreshStatus() }
                        } label: {
                            if isChecking {
                                ProgressView().tint(Palette.onGold)
                            } else {
                                Text("Проверить статус доступа")
                            }
                        }
                        .buttonStyle(GoldButton())
                        .disabled(isChecking)
                    } else {
                        Text("Если у вас уже активирован доступ Spartan Pro, войдите по вашему Email.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.marble)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Войти по Email") {
                            showEmailLink = true
                        }
                        .buttonStyle(GoldButton())
                    }

                    if let statusNote {
                        Text(statusNote)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.ash)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await subscriptions.openExternalWebsite() }
                    } label: {
                        Label("Узнать подробнее о программе", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(EngravedButton())

                    Text("Spartan Pro является единой кросс-платформенной системой. Доступ синхронизируется через ваш аккаунт.")
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
        .sheet(isPresented: $showEmailLink) {
            EmailLinkSheet(purpose: .signIn)
        }
        .onChange(of: subscriptions.isPro) { _, unlocked in
            if unlocked { dismiss() }
        }
        .presentationDragIndicator(.visible)
        .task { await subscriptions.checkSubscription() }
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

    private func benefit(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.goldFill)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
        }
    }
}
