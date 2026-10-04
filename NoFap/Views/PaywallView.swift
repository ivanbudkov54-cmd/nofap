//
//  PaywallView.swift
//  NoFap
//
//  Нативный экран Pro: два тарифа, восстановление покупок и ссылки
//  на политику и соглашение — так требует App Store.
//

import SwiftUI

struct PaywallView: View {

    var contextReason: String = ""

    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private enum Offer {
        case yearly, monthly, lifetime
    }

    @State private var offer: Offer = .yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Разблокируй полную перезагрузку и контроль")
                        .font(Face.display(28, .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                        .fixedSize(horizontal: false, vertical: true)

                    if !contextReason.isEmpty {
                        Text("Разблокируй: \(L10n.string(contextReason))")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.marbleHigh)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        benefit("Аналитика триггеров и недели")
                        benefit("Оповещение напарника в момент SOS")
                        benefit("Полная база знаний и научные статьи")
                        benefit("Дневник энергии и тонуса")
                        benefit("Прокачка аватара")
                    }

                    planButton(
                        title: "Годовая подписка",
                        price: yearlyPrice,
                        detail: RegionHelper.isRussia ? nil : "3 дня бесплатно",
                        badge: "Выгода 50%",
                        selected: offer == .yearly
                    ) { offer = .yearly }

                    planButton(
                        title: "Месячная подписка",
                        price: monthlyPrice,
                        detail: nil,
                        badge: nil,
                        selected: offer == .monthly
                    ) { offer = .monthly }

                    planButton(
                        title: "Навсегда",
                        price: lifetimePrice,
                        detail: nil,
                        badge: nil,
                        selected: offer == .lifetime
                    ) { offer = .lifetime }

                    if RegionHelper.isRussia {
                        Button {
                            openURL(RegionHelper.russianPaymentURL)
                        } label: {
                            Text("Оплата российскими картами / СБП")
                        }
                        .buttonStyle(GoldButton())
                    } else {
                        Button {
                            Task {
                                switch offer {
                                case .yearly: await subscriptions.purchaseYearly()
                                case .monthly: await subscriptions.purchaseMonthly()
                                case .lifetime: await subscriptions.purchaseLifetime()
                                }
                                if subscriptions.isPro { dismiss() }
                            }
                        } label: {
                            if subscriptions.isBusy {
                                ProgressView()
                            } else {
                                Text(offer == .yearly ? "Попробовать 3 дня бесплатно" : "Продолжить")
                            }
                        }
                        .buttonStyle(GoldButton())
                        .disabled(subscriptions.isBusy)

                        Button("Восстановить покупки") {
                            Task {
                                await subscriptions.restorePurchases()
                                if subscriptions.isPro { dismiss() }
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.ash)
                        .frame(maxWidth: .infinity)
                        .disabled(subscriptions.isBusy)
                    }

                    if let lastError = subscriptions.lastError {
                        Text(lastError)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ash)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        NavigationLink("Политика конфиденциальности") {
                            SettingsView.LegalDocumentView(title: "Политика конфиденциальности", resource: "privacy")
                        }
                        Text("·").foregroundStyle(Palette.ash)
                        NavigationLink("Условия использования") {
                            SettingsView.LegalDocumentView(title: "Условия использования", resource: "terms")
                        }
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)

                    Text("Подписка продлевается автоматически, пока её не отменят в настройках Apple ID. Условия и политика конфиденциальности действуют на весь срок доступа.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Palette.ash)
                }
            }
        }
        .task { await subscriptions.loadOffers() }
        .presentationDragIndicator(.visible)
    }

    private var yearlyPrice: String {
        RegionHelper.isRussia ? "1 490 ₽" : "$29.99"
    }

    private var monthlyPrice: String {
        RegionHelper.isRussia ? "299 ₽" : "$4.99"
    }

    private var lifetimePrice: String {
        RegionHelper.isRussia ? "2 490 ₽" : "$49.99"
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.gold)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marble)
        }
    }

    private func planButton(title: LocalizedStringKey, price: String, detail: LocalizedStringKey?, badge: LocalizedStringKey?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.marbleHigh)
                    Text(price)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ash)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.gold)
                    }
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1A1405))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.goldFill))
                }
            }
            .padding(16)
            .background(Palette.basalt, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Palette.gold : Palette.vein, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProLockBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("PRO")
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color(hex: 0x1A1405))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Palette.gold))
    }
}
