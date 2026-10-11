//
//  WebPremium.swift
//  NoFap
//
//  Premium, оплаченный на сайте через Lemon Squeezy, — только для
//  американского App Store: там Apple разрешает ссылку на оплату вне
//  приложения. Остальные видят только покупку через Apple.
//
//  Два пути открыть Premium:
//  - сайт получает id аккаунта (`?u=`), вебхук записывает подписку в
//    web_premium (supabase/04_web_premium.sql) — приложение её читает;
//  - ключ из письма-чека: его проверяет License API Lemon Squeezy. Нужен,
//    если приложение переустановили и анонимный аккаунт потерялся.
//

import Foundation
import StoreKit

enum LemonSqueezyConfig {

    /// Лендинг с оплатой (репозиторий premium на GitHub Pages).
    static let landingURL = URL(string: "https://ivanbudkov54-cmd.github.io/premium/")!

    /// Lemon Squeezy → Settings → Stores → ID магазина. Пока 0, оплата на
    /// сайте выключена: ни кнопки, ни ввода ключа.
    static let storeID = 0

    static var isReady: Bool { storeID != 0 }

    /// Цена годовой подписки на сайте — как на лендинге.
    static let yearlyPrice = "$20"
}

@MainActor
@Observable
final class WebPremium {

    /// Подписка с сайта действует — по серверу или по ключу.
    private(set) var isActive = false

    /// Американская витрина App Store: только там показываем оплату на сайте.
    private(set) var isUSStorefront = false

    private(set) var hasLicenseKey: Bool

    var offersWebCheckout: Bool {
        LemonSqueezyConfig.isReady && isUSStorefront || debugOverride
    }

    private var serverActive = false
    private var licenseActive: Bool
    /// Когда открыли оплату на сайте: вернувшись, ждём вебхук подольше.
    private var checkoutOpenedAt: Date?
    private var isRefreshing = false

    private let client = SupabaseClient(session: .shared)
    private let defaults: UserDefaults

    private enum Key {
        static let licenseKey = "lemon.licenseKey"
        static let instanceID = "lemon.instanceID"
        static let licenseValidUntil = "lemon.licenseValidUntil"
    }

    /// Без сети ключу верим ещё столько после последней удачной проверки.
    private static let offlineGrace: TimeInterval = 14 * 24 * 3600

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hasKey = Keychain.read(Key.licenseKey) != nil
        let validUntil = defaults.object(forKey: Key.licenseValidUntil) as? Date
        hasLicenseKey = hasKey
        licenseActive = hasKey && (validUntil ?? .distantPast) > Date()
        isActive = licenseActive
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        isUSStorefront = await Storefront.current?.countryCode == "USA"
        guard LemonSqueezyConfig.isReady else { return }

        await refreshLicense()
        await refreshServer()

        // Вебхук приходит через несколько секунд после оплаты — если
        // человек только что вернулся с сайта, подождём его.
        if let opened = checkoutOpenedAt, Date().timeIntervalSince(opened) < 30 * 60 {
            for _ in 0..<5 where !serverActive {
                try? await Task.sleep(for: .seconds(3))
                await refreshServer()
            }
            if serverActive { checkoutOpenedAt = nil }
        }
    }

    /// Ссылка на лендинг с id аккаунта — по нему вебхук найдёт, кому открыть Premium.
    func checkoutURL() async -> URL {
        checkoutOpenedAt = Date()
        guard let uid = try? await SupabaseSession.shared.userID() else {
            return LemonSqueezyConfig.landingURL
        }
        var components = URLComponents(url: LemonSqueezyConfig.landingURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "u", value: uid)]
        return components.url ?? LemonSqueezyConfig.landingURL
    }

    // MARK: - Ключ из письма

    enum KeyError: Error {
        case invalid, expired, foreignStore, limitReached, network
    }

    /// Активирует ключ на этом телефоне. Ключ из чужого магазина Lemon
    /// Squeezy не подойдёт — проверяем store_id.
    func activate(key raw: String) async throws {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw KeyError.invalid }

        let response: LicenseResponse
        do {
            response = try await licenseCall("activate", ["license_key": key,
                                                         "instance_name": "iPhone"])
        } catch {
            throw KeyError.network
        }

        guard response.meta?.storeId == LemonSqueezyConfig.storeID else {
            throw response.licenseKey == nil ? KeyError.invalid : KeyError.foreignStore
        }
        guard response.activated == true, let instance = response.instance else {
            if response.licenseKey?.isUsable == false { throw KeyError.expired }
            if let limit = response.licenseKey?.activationLimit,
               let usage = response.licenseKey?.activationUsage, usage >= limit {
                throw KeyError.limitReached
            }
            throw KeyError.invalid
        }

        Keychain.write(Key.licenseKey, key)
        Keychain.write(Key.instanceID, instance.id)
        hasLicenseKey = true
        setLicense(active: response.licenseKey?.isUsable ?? false)
    }

    private func refreshLicense() async {
        guard let key = Keychain.read(Key.licenseKey),
              let instance = Keychain.read(Key.instanceID) else { return }
        guard let response = try? await licenseCall("validate", ["license_key": key,
                                                                 "instance_id": instance]) else {
            // Нет сети — остаёмся на сохранённом сроке.
            return
        }
        let usable = response.valid == true
            && response.meta?.storeId == LemonSqueezyConfig.storeID
            && response.licenseKey?.isUsable == true
        setLicense(active: usable)
    }

    private func setLicense(active: Bool) {
        licenseActive = active
        defaults.set(active ? Date().addingTimeInterval(Self.offlineGrace) : nil,
                     forKey: Key.licenseValidUntil)
        isActive = licenseActive || serverActive
    }

    /// License API Lemon Squeezy открытый: ключ API не нужен и не хранится
    /// в приложении.
    private func licenseCall(_ action: String, _ form: [String: String]) async throws -> LicenseResponse {
        var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/licenses/\(action)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // На неверный ключ API отвечает 400/404 с тем же JSON — разбираем его.
        guard status < 500 else { throw URLError(.badServerResponse) }
        return try Self.decoder.decode(LicenseResponse.self, from: data)
    }

    // MARK: - Сервер

    private func refreshServer() async {
        guard SupabaseConfig.isConfigured,
              let uid = try? await SupabaseSession.shared.userID(),
              let rows: [WebPremiumRow] = try? await client.select(
                  "web_premium", [("user_id", "eq.\(uid)")],
                  columns: "status,ends_at,refunded")
        else { return }
        serverActive = rows.contains(where: \.grantsPremium)
        isActive = licenseActive || serverActive
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// `-webCheckoutOverride YES` — показать оплату на сайте вне США.
    private var debugOverride: Bool {
        #if DEBUG
        defaults.bool(forKey: "webCheckoutOverride")
        #else
        false
        #endif
    }
}

// MARK: - Ответы

private struct LicenseResponse: Decodable {
    let activated: Bool?
    let valid: Bool?
    let licenseKey: LicenseKey?
    let instance: Instance?
    let meta: Meta?

    struct LicenseKey: Decodable {
        let status: String
        let activationLimit: Int?
        let activationUsage: Int?

        /// inactive — ключ ещё не активирован ни на одном устройстве, но действует.
        var isUsable: Bool { status == "active" || status == "inactive" }
    }

    struct Instance: Decodable { let id: String }
    struct Meta: Decodable { let storeId: Int }
}

private struct WebPremiumRow: Decodable {
    let status: String
    let endsAt: Date?
    let refunded: Bool

    /// Статусы подписки Lemon Squeezy. Отменённая действует до конца
    /// оплаченного года.
    var grantsPremium: Bool {
        guard !refunded else { return false }
        switch status {
        case "active", "on_trial", "past_due": return true
        case "cancelled": return (endsAt ?? .distantPast) > Date()
        default: return false
        }
    }
}
