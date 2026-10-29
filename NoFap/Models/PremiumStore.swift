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
import UIKit

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

    /// Подписка в App Store.
    private(set) var hasStoreSubscription = false

    /// Premium, оплаченный на сайте (только американский App Store).
    let web = WebPremium()

    /// true — всё открыто бесплатно (Pro не продаётся).
    static let freeLaunch = false

    /// Spartan Pro по статусу аккаунта: оплата на сайте (Робокасса) пишет
    /// profiles.is_pro / pro_expires_at, приложение только читает.
    private(set) var accountPro = UserDefaults.standard.bool(forKey: AccountKey.pro)
    private(set) var expiresAt: Date? = UserDefaults.standard.object(forKey: AccountKey.expiresAt) as? Date
    private(set) var accountEmail: String? = UserDefaults.standard.string(forKey: AccountKey.email)
    var hasLinkedEmail: Bool { accountEmail?.isEmpty == false }

    private enum AccountKey {
        static let pro = "webProActive"
        static let expiresAt = "webProExpiresAt"
        static let email = "linkedAccountEmail"
    }

    private var accountActive: Bool {
        accountPro && (expiresAt.map { $0 > Date() } ?? true)
    }

    var isPremium: Bool {
        Self.freeLaunch || hasStoreSubscription || accountActive || web.isActive || debugOverride
    }

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
        guard !Self.freeLaunch else { return }
        await checkSubscription()
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
        hasStoreSubscription = active
        // Не ждём: проверка сайта ходит в сеть и не должна тормозить покупку.
        Task { await web.refresh() }
        Task { await checkSubscription() }
    }

    // MARK: - Spartan Pro по аккаунту

    enum SubscriptionRefresh { case active, inactive, unavailable }

    private let db = SupabaseClient(session: .shared)

    private struct ProProfileRow: Decodable {
        let email: String?
        let isPro: Bool
        let proExpiresAt: Date?
    }

    /// Читает is_pro и pro_expires_at текущего профиля, в том числе анонимного:
    /// сайт получает user_id из приложения, и вебхук пишет доступ на этот id.
    @discardableResult
    func checkSubscription() async -> SubscriptionRefresh {
        guard SupabaseConfig.isConfigured,
              let uid = try? await SupabaseSession.shared.userID()
        else { return .unavailable }
        try? await db.call("claim_pro")
        guard let rows: [ProProfileRow] = try? await db.select(
            "profiles", [("id", "eq.\(uid)")], columns: "email,is_pro,pro_expires_at")
        else { return .unavailable }
        let row = rows.first
        if let email = row?.email, !email.isEmpty { noteLinkedAccount(email: email) }
        applyAccount(isPro: row?.isPro ?? false, expiresAt: row?.proExpiresAt)
        return accountActive ? .active : .inactive
    }

    func noteLinkedAccount(email: String) {
        accountEmail = email
        UserDefaults.standard.set(email, forKey: AccountKey.email)
    }

    private func applyAccount(isPro: Bool, expiresAt: Date?) {
        accountPro = isPro
        self.expiresAt = expiresAt
        let defaults = UserDefaults.standard
        defaults.set(isPro, forKey: AccountKey.pro)
        defaults.set(expiresAt, forKey: AccountKey.expiresAt)
        if isPremium { shouldShowPaywall = false }
    }

    static let websiteBase = "https://spartan-pro.ru"

    /// Системный браузер: https://spartan-pro.ru{path}?user_id=…&email=…
    func openExternalWebsite(targetPath: String = "") async {
        guard var components = URLComponents(string: Self.websiteBase + targetPath) else { return }
        var items = [URLQueryItem]()
        if let uid = try? await SupabaseSession.shared.userID() {
            items.append(URLQueryItem(name: "user_id", value: uid))
        }
        if let accountEmail, !accountEmail.isEmpty {
            items.append(URLQueryItem(name: "email", value: accountEmail))
        }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else { return }
        await UIApplication.shared.open(url)
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
