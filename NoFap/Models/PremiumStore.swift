//
//  PremiumStore.swift
//  NoFap
//
//  Подписка Premium на StoreKit 2. Что закрыто подпиской: «Мой путь»
//  после первой недели, аналитика триггеров, умные напоминания. Всё, что
//  помогает в момент тяги (SOS, стрик, срыв, напарник), бесплатно всегда:
//  упереться в пейволл посреди тяги — худшее, что может сделать такое
//  приложение.
//

import Foundation
import StoreKit

@Observable
@MainActor
final class PremiumStore {

    enum ProductID {
        static let yearly = "Albert.lvan.NoFap.premium.yearly"
        static let monthly = "Albert.lvan.NoFap.premium.monthly"
        /// Порядок = порядок на экране подписки: годовая первой.
        static let all = [yearly, monthly]
    }

    enum LoadState { case idle, loading, loaded, failed }

    enum PurchaseOutcome { case purchased, pending, cancelled, failed }

    /// Сколько дней «Моего пути» открыто без подписки.
    static let freeJourneyDays = 7

    private(set) var isPremium = false

    /// Пейвол по требованию экрана: `checkProAccess` поднимает флаг, RootView
    /// показывает PaywallView. Причина — короткая строка над тарифами.
    var shouldShowPaywall = false
    var paywallContextReason = ""

    /// Экраны друга называют Premium «Pro» — одно и то же.
    var isPro: Bool { isPremium }

    func checkProAccess(for reason: String, onGranted: () -> Void) {
        if isPremium {
            onGranted()
        } else {
            paywallContextReason = reason
            shouldShowPaywall = true
        }
    }
    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var isTrialEligible = false
    private(set) var purchasingID: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Покупки, завершившиеся вне приложения: продление, Ask to Buy,
        // покупка на другом устройстве, возврат денег.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }

    func start() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = ProductID.all.compactMap { id in fetched.first { $0.id == id } }
            isTrialEligible = await products.first?.subscription?.isEligibleForIntroOffer ?? false
            loadState = products.isEmpty ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    /// Подписка истекает без всякого события, поэтому это зовётся и при
    /// каждом возвращении в приложение.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active || debugOverride
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        purchasingID = product.id
        defer { purchasingID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// true — подписка нашлась.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isPremium
    }

    // MARK: - Отладка

    /// `-premiumOverride YES` в аргументах запуска — посмотреть приложение
    /// глазами подписчика без тестовой покупки.
    private var debugOverride: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "premiumOverride")
        #else
        false
        #endif
    }
}

extension Product {

    var isYearly: Bool { id == PremiumStore.ProductID.yearly }

    /// «29,99 $ в год» / «4,99 $ в месяц».
    var pricePerPeriod: String {
        isYearly
            ? String(localized: "\(displayPrice) в год")
            : String(localized: "\(displayPrice) в месяц")
    }
}
