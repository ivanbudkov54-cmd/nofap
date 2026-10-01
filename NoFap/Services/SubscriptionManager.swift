//
//  SubscriptionManager.swift
//  NoFap
//
//  Pro-доступ через RevenueCat. Entitlement в кабинете RevenueCat: pro_access.
//  Продукты локального StoreKit: stopfap_yearly_pro, stopfap_monthly_pro.
//

import Foundation
import RevenueCat
import UIKit

@MainActor
@Observable
final class SubscriptionManager {

    static let entitlementID = "pro_access"
    static let yearlyProductID = "stopfap_yearly_pro"
    static let monthlyProductID = "stopfap_monthly_pro"

    private(set) var isPro = false
    var isProUser: Bool { isPro }
    var shouldShowPaywall = false
    var paywallContextReason = ""
    private(set) var yearly: Package?
    private(set) var monthly: Package?
    private(set) var yearlyProduct: StoreProduct?
    private(set) var monthlyProduct: StoreProduct?
    var yearlyPriceText: String {
        yearly?.storeProduct.localizedPriceString
            ?? yearlyProduct?.localizedPriceString
            ?? "$29.99/год"
    }

    var monthlyPriceText: String {
        monthly?.storeProduct.localizedPriceString
            ?? monthlyProduct?.localizedPriceString
            ?? "$4.99/месяц"
    }

    var lastError: String?
    var isBusy = false
    private var listening = false

    func checkProAccess(for reason: String, onGranted: () -> Void) {
        if isPro {
            onGranted()
        } else {
            paywallContextReason = reason
            shouldShowPaywall = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func checkSubscriptionStatus() async {
        startListening()
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Привязывает покупки к анонимному id Supabase, когда сессия уже есть.
    func identify(_ userId: String) async {
        startListening()
        do {
            let (info, _) = try await Purchases.shared.logIn(userId)
            apply(info)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadOffers() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let packages = offerings.current?.availablePackages ?? []
            yearly = packages.first { $0.storeProduct.productIdentifier == Self.yearlyProductID }
                ?? packages.first { $0.packageType == .annual }
            monthly = packages.first { $0.storeProduct.productIdentifier == Self.monthlyProductID }
                ?? packages.first { $0.packageType == .monthly }
        } catch {
            lastError = error.localizedDescription
        }

        if yearly == nil || monthly == nil {
            let products = await Purchases.shared.products([Self.yearlyProductID, Self.monthlyProductID])
            yearlyProduct = products.first { $0.productIdentifier == Self.yearlyProductID }
            monthlyProduct = products.first { $0.productIdentifier == Self.monthlyProductID }
        }
    }

    func purchase(package: Package) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            lastError = result.userCancelled ? nil : nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchaseYearly() async {
        if let yearly {
            await purchase(package: yearly)
        } else if let yearlyProduct {
            await purchase(product: yearlyProduct)
        } else {
            lastError = "Годовой тариф ещё не загрузился из StoreKit."
        }
    }

    func purchaseMonthly() async {
        if let monthly {
            await purchase(package: monthly)
        } else if let monthlyProduct {
            await purchase(product: monthlyProduct)
        } else {
            lastError = "Месячный тариф ещё не загрузился из StoreKit."
        }
    }

    func restorePurchases() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            lastError = isPro ? nil : "Активных покупок не найдено."
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func purchase(product: StoreProduct) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            apply(result.customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startListening() {
        guard !listening else { return }
        listening = true
        Task { await listen() }
    }

    private func listen() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
    }
}
