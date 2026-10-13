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
    static let lifetimeProductID = "stopfap_lifetime_pro"

    enum SubscriptionRefresh {
        case active
        case inactive
        case unavailable
    }

    private enum CacheKey {
        static let webPro = "webProActive"
        static let expiresAt = "webProExpiresAt"
    }

    static let websiteBase = "https://spartan-pro.ru"

    private(set) var isPro = false
    private(set) var expiresAt: Date? = UserDefaults.standard.object(forKey: CacheKey.expiresAt) as? Date
    private(set) var accountEmail: String? = LinkedAccount.email
    var hasLinkedEmail: Bool { accountEmail?.isEmpty == false }
    var isProUser: Bool { isPro }
    private var storePro = false
    private var webPro = UserDefaults.standard.bool(forKey: CacheKey.webPro)
    private var accountUserId: UUID?

    init() {
        publishAccess()
    }
    private let realtime = ProfileRealtime()
    var shouldShowPaywall = false
    var paywallContextReason = ""
    private(set) var yearly: Package?
    private(set) var monthly: Package?
    private(set) var yearlyProduct: StoreProduct?
    private(set) var monthlyProduct: StoreProduct?
    private(set) var lifetimeProduct: StoreProduct?
    var yearlyPriceText: String {
        yearly?.storeProduct.localizedPriceString
            ?? yearlyProduct?.localizedPriceString
            ?? ""
    }

    var monthlyPriceText: String {
        monthly?.storeProduct.localizedPriceString
            ?? monthlyProduct?.localizedPriceString
            ?? ""
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
            lifetimeProduct = packages.first { $0.storeProduct.productIdentifier == Self.lifetimeProductID }?.storeProduct
                ?? packages.first { $0.packageType == .lifetime }?.storeProduct
        } catch {
            lastError = error.localizedDescription
        }

        if yearly == nil || monthly == nil || lifetimeProduct == nil {
            let products = await Purchases.shared.products([
                Self.yearlyProductID, Self.monthlyProductID, Self.lifetimeProductID
            ])
            yearlyProduct = products.first { $0.productIdentifier == Self.yearlyProductID }
            monthlyProduct = products.first { $0.productIdentifier == Self.monthlyProductID }
            lifetimeProduct = products.first { $0.productIdentifier == Self.lifetimeProductID }
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

    func purchaseLifetime() async {
        if let lifetimeProduct {
            await purchase(product: lifetimeProduct)
        } else {
            lastError = "Пожизненный тариф ещё не загрузился из StoreKit."
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

    /// Читает is_pro и pro_expires_at текущего профиля, в том числе анонимного:
    /// сайт получает user_id из приложения и вебхук пишет доступ на этот id.
    @discardableResult
    func checkSubscription(backend: Backend) async -> SubscriptionRefresh {
        guard let profile = await backend.fetchProProfile() else { return .unavailable }
        accountUserId = backend.currentUserId()
        if let email = profile.email, !email.isEmpty {
            accountEmail = email
            UserDefaults.standard.set(email, forKey: LinkedAccount.emailKey)
        }
        applyWeb(isPro: profile.isPro, expiresAt: profile.expiresAt)
        if let accountUserId, let token = backend.currentAccessToken() {
            realtime.start(userId: accountUserId, accessToken: token) { [weak self] isPro, expires in
                self?.applyWeb(isPro: isPro, expiresAt: expires)
            }
        }
        let webActive = profile.isPro && (profile.expiresAt.map { $0 > Date() } ?? true)
        return webActive ? .active : .inactive
    }

    func noteLinkedAccount(userId: UUID, email: String) {
        accountUserId = userId
        accountEmail = email
        UserDefaults.standard.set(email, forKey: LinkedAccount.emailKey)
    }

    /// Системный браузер: https://spartan-pro.ru{path}?user_id=…&email=…
    func openExternalWebsite(backend: Backend, targetPath: String = "") {
        guard var components = URLComponents(string: Self.websiteBase + targetPath) else { return }
        var items = [URLQueryItem]()
        if let userId = accountUserId ?? backend.currentUserId() {
            items.append(URLQueryItem(name: "user_id", value: userId.uuidString))
        }
        if let accountEmail, !accountEmail.isEmpty {
            items.append(URLQueryItem(name: "email", value: accountEmail))
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private func apply(_ info: CustomerInfo) {
        storePro = info.entitlements[Self.entitlementID]?.isActive == true
        publishAccess()
    }

    private func applyWeb(isPro: Bool, expiresAt: Date?) {
        webPro = isPro
        self.expiresAt = expiresAt
        let defaults = UserDefaults.standard
        defaults.set(isPro, forKey: CacheKey.webPro)
        if let expiresAt {
            defaults.set(expiresAt, forKey: CacheKey.expiresAt)
        } else {
            defaults.removeObject(forKey: CacheKey.expiresAt)
        }
        publishAccess()
    }

    private func publishAccess() {
        let webActive = webPro && (expiresAt.map { $0 > Date() } ?? true)
        isPro = storePro || webActive
        if isPro {
            shouldShowPaywall = false
        }
    }
}

/// Слушает postgres changes по public.profiles для текущего пользователя.
@MainActor
private final class ProfileRealtime {
    private var socket: URLSessionWebSocketTask?
    private var heartbeat: Task<Void, Never>?
    private var receiveLoop: Task<Void, Never>?
    private var onUpdate: ((Bool, Date?) -> Void)?

    func start(userId: UUID, accessToken: String, onUpdate: @escaping (Bool, Date?) -> Void) {
        stop()
        self.onUpdate = onUpdate
        guard var components = URLComponents(string: SupabaseConfig.url) else { return }
        components.scheme = "wss"
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: SupabaseConfig.anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        guard let url = components.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        send([
            "topic": "realtime:public:profiles",
            "event": "phx_join",
            "payload": [
                "access_token": accessToken,
                "config": [
                    "postgres_changes": [[
                        "event": "*",
                        "schema": "public",
                        "table": "profiles",
                        "filter": "id=eq.\(userId.uuidString)"
                    ]]
                ]
            ],
            "ref": "1"
        ])
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                self?.send(["topic": "phoenix", "event": "heartbeat", "payload": [String: String](), "ref": "hb"])
            }
        }
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.receiveOnce()
            }
        }
    }

    private func receiveOnce() async {
        guard let socket else { return }
        guard let message = try? await socket.receive() else {
            stop()
            return
        }
        let text: String
        switch message {
        case .string(let value):
            text = value
        case .data(let data):
            text = String(decoding: data, as: UTF8.self)
        @unknown default:
            return
        }
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = json["payload"] as? [String: Any],
            let dataNode = payload["data"] as? [String: Any],
            let record = dataNode["record"] as? [String: Any]
        else { return }
        let flag = record["is_pro"] as? Bool ?? false
        let raw = record["pro_expires_at"] as? String
        onUpdate?(flag, raw.flatMap(Self.parseDate))
    }

    private func send(_ object: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: object),
            let text = String(data: data, encoding: .utf8)
        else { return }
        socket?.send(.string(text)) { _ in }
    }

    private func stop() {
        heartbeat?.cancel()
        receiveLoop?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        heartbeat = nil
        receiveLoop = nil
        socket = nil
    }

    private static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
