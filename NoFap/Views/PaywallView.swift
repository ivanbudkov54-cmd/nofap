//
//  PaywallView.swift
//  NoFap
//
//  Экран подписки. Спокойный, без таймеров «осталось 5 минут» и
//  зачёркнутых цен: человек пришёл сюда работать над собой, давить на
//  него дешёвыми приёмами — против самого смысла приложения.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(PremiumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedID = PremiumStore.ProductID.yearly
    @State private var notice: Notice?

    private enum Notice: String, Identifiable {
        case pending, failed, nothingToRestore
        var id: String { rawValue }
    }

    private var selected: Product? {
        store.products.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 26) {
                    header
                    benefits
                    plans
                    purchaseButton
                    fineprint
                }
                .padding(.horizontal, 22)
                .padding(.top, 56)
                .padding(.bottom, 28)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ash)
                    .frame(width: 36, height: 36)
                    .background(Palette.basalt, in: .circle)
            }
            .accessibilityLabel(Text("Закрыть"))
            .padding(16)
        }
        .background(StoneBackground())
        .task {
            if store.loadState != .loaded { await store.loadProducts() }
        }
        .onChange(of: store.isPremium) { _, premium in
            if premium { dismiss() }
        }
        .alert(item: $notice) { notice in
            switch notice {
            case .pending:
                Alert(title: Text("Покупка ждёт подтверждения"),
                      message: Text("Как только её одобрят, Premium откроется сам."))
            case .failed:
                Alert(title: Text("Не получилось"),
                      message: Text("Покупка не прошла. Деньги не списаны — попробуй ещё раз."))
            case .nothingToRestore:
                Alert(title: Text("Покупок не найдено"),
                      message: Text("На этом Apple ID нет активной подписки."))
            }
        }
    }

    // MARK: - Части

    private var header: some View {
        VStack(spacing: 10) {
            Eyebrow(text: "premium", color: Palette.gold)

            Text("Иди дальше первой недели")
                .font(Face.display(26, .semibold))
                .foregroundStyle(.goldFill)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Всё, что помогает в момент тяги, остаётся бесплатным. Premium — для тех, кто хочет понять себя глубже.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefit("map", "Весь «Мой путь»",
                    "90 дней вместо 7: что происходит с телом и головой на каждом этапе")
            benefit("chart.bar.xaxis", "Аналитика триггеров",
                    "Когда и почему тянет чаще всего — чтобы готовиться заранее")
            benefit("bell.badge", "Умные напоминания",
                    "По твоему настоящему опасному часу, а не по ответу из анкеты")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringResource, _ note: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.goldFill)
                .frame(width: 36, height: 36)
                .background(Palette.gold.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    planRow(product)
                }
            }
        case .failed:
            VStack(spacing: 12) {
                Text("Не удалось загрузить варианты подписки. Проверь интернет.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                Button("Повторить") { Task { await store.loadProducts() } }
                    .buttonStyle(StoneButton())
            }
        case .idle, .loading:
            ProgressView()
                .tint(Palette.gold)
                .frame(height: 140)
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = product.id == selectedID

        return Button {
            withAnimation(.snappy(duration: 0.2)) { selectedID = product.id }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.isYearly ? "Год" : "Месяц")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        if product.isYearly, let saving = yearlySaving {
                            Text("−\(saving)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: 0x1A1405))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.goldFill))
                        }
                    }
                    if product.isYearly, let monthly = perMonth(product) {
                        Text("\(monthly) в месяц")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ash)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.marbleHigh)
            }
            .padding(16)
            .background(Palette.basalt, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? AnyShapeStyle(.goldFill) : AnyShapeStyle(Palette.vein),
                                  lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            guard let selected else { return }
            Task {
                switch await store.purchase(selected) {
                case .purchased, .cancelled: break
                case .pending: notice = .pending
                case .failed:  notice = .failed
                }
            }
        } label: {
            if store.purchasingID != nil {
                ProgressView().tint(Color(hex: 0x1A1405))
            } else {
                Text(store.isTrialEligible ? "Попробовать 7 дней бесплатно" : "Оформить Premium")
            }
        }
        .buttonStyle(GoldButton())
        .disabled(selected == nil || store.purchasingID != nil)
        .opacity(selected == nil ? 0.5 : 1)
    }

    /// Apple требует показать цену, период и условия продления до покупки.
    private var fineprint: some View {
        VStack(spacing: 14) {
            if let selected {
                Text(renewalTerms(for: selected))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 18) {
                Button("Восстановить покупки") {
                    Task {
                        if !(await store.restore()) { notice = .nothingToRestore }
                    }
                }
                Button("Условия") {
                    openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.marble)
        }
    }

    // MARK: - Расчёты

    private func renewalTerms(for product: Product) -> String {
        let price = product.pricePerPeriod
        let tail = String(localized: "Подписка продлевается автоматически. Отменить можно в любой момент в настройках Apple ID, но не позже чем за сутки до конца периода.")
        return store.isTrialEligible
            ? String(localized: "7 дней бесплатно, затем \(price).") + " " + tail
            : "\(price). " + tail
    }

    private var yearlySaving: Int? {
        guard let yearly = store.products.first(where: \.isYearly),
              let monthly = store.products.first(where: { !$0.isYearly }),
              monthly.price > 0 else { return nil }
        let ratio = (yearly.price / (monthly.price * 12) as NSDecimalNumber).doubleValue
        let saving = Int(((1 - ratio) * 100).rounded())
        return saving > 0 ? saving : nil
    }

    private func perMonth(_ product: Product) -> String? {
        (product.price / 12).formatted(product.priceFormatStyle)
    }
}
