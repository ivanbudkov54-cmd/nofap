//
//  SubscriptionStatusView.swift
//  NoFap
//
//  Статус доступа по email. Экран не ведёт на оплату и не называет цены.
//

import SwiftUI

struct SubscriptionStatusView: View {

    @Environment(PremiumStore.self) private var subscriptions

    @State private var showEmailLink = false
    @State private var isChecking = false
    @State private var alertText: String?

    var body: some View {
        List {
            Section("Текущий статус") {
                if subscriptions.isPro {
                    if let expiresAt = subscriptions.expiresAt {
                        Text("Spartan Pro активен до \(expiresAt.formatted(date: .long, time: .omitted))")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                    } else {
                        Text("Spartan Pro активен")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                    }
                    Button("Синхронизировать") {
                        Task { await refresh(report: false) }
                    }
                    .disabled(isChecking)
                } else {
                    Text("Базовый доступ")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Button("Войти в другой аккаунт") {
                        showEmailLink = true
                    }
                }
            }

            Section {
                Button("Обновить статус") {
                    Task { await refresh(report: true) }
                }
                .disabled(isChecking)

                Button {
                    Task { await subscriptions.openExternalWebsite() }
                } label: {
                    HStack {
                        Text("Информация о сервисе на сайте")
                            .foregroundStyle(Palette.marbleHigh)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ash)
                    }
                }
            }

            Section {
                Text("Управление статусом программы и доступ на других платформах привязаны к вашему Email: \(subscriptions.accountEmail ?? "Не привязан")")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.obsidian.ignoresSafeArea())
        .tint(Palette.gold)
        .navigationTitle("Управление подпиской")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEmailLink) {
            EmailLinkSheet(purpose: .signIn)
        }
        .alert("Статус доступа", isPresented: Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(alertText ?? "")
        }
    }

    private func refresh(report: Bool) async {
        isChecking = true
        defer { isChecking = false }
        let result = await subscriptions.checkSubscription()
        guard report else { return }
        switch result {
        case .active:
            alertText = "Доступ успешно активирован!"
        case .inactive:
            alertText = "Активная подписка для данного email не найдена."
        case .unavailable:
            alertText = "Не удалось обновить статус. Проверьте соединение."
        }
    }
}
