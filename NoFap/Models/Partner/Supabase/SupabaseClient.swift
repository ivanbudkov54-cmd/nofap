//
//  SupabaseClient.swift
//  NoFap
//
//  Тонкий клиент PostgREST — REST-слоя Supabase над Postgres. Два вида
//  запросов: вызвать функцию (всё, что меняет данные) и прочитать таблицу
//  (только то, что разрешают политики RLS).
//

import Foundation

enum SupabaseError: Error {
    /// Функция отказала своим кодом (`code_not_found`, `already_paired`…).
    case rejected(String)
    case denied
    case server(Int)
}

@MainActor
final class SupabaseClient {

    private let session: SupabaseSession

    init(session: SupabaseSession) {
        self.session = session
    }

    /// Вызов функции из supabase/schema.sql, результат — одна строка.
    func call<Result: Decodable>(_ function: String, _ args: [String: Any?] = [:]) async throws -> Result {
        let data = try await send("POST", "rpc/\(function)", json: args)
        return try Self.decoder.decode(Result.self, from: data)
    }

    /// Вызов функции без результата.
    func call(_ function: String, _ args: [String: Any?] = [:]) async throws {
        _ = try await send("POST", "rpc/\(function)", json: args)
    }

    /// Чтение таблицы с фильтрами PostgREST (`id=eq.…`, `order=…`).
    func select<Row: Decodable>(_ table: String, _ filters: [(String, String)]) async throws -> [Row] {
        let data = try await send("GET", table, query: [("select", "*")] + filters)
        return try Self.decoder.decode([Row].self, from: data)
    }

    // MARK: - Внутреннее

    private func send(_ method: String,
                      _ path: String,
                      query: [(String, String)] = [],
                      json: [String: Any?]? = nil,
                      isRetry: Bool = false) async throws -> Data {
        var components = URLComponents(string: "\(SupabaseConfig.url)/rest/v1/\(path)")!
        if !query.isEmpty {
            // «+» в значениях (часовой пояс) в query-строке читается как
            // пробел — кодируем его явно.
            components.percentEncodedQueryItems = query.map {
                URLQueryItem(name: $0.0, value: Self.encode($0.1))
            }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try await session.token())", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json.mapValues { $0 ?? NSNull() })
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // Токен отозвали раньше срока — один раз берём новый и повторяем.
        if status == 401, !isRetry {
            session.invalidate()
            return try await send(method, path, query: query, json: json, isRetry: true)
        }

        switch status {
        case 200..<300:
            return data
        case 400:
            // Отказ функции: `raise exception 'code_not_found'` приходит
            // как 400 с кодом P0001 и нашим текстом в message.
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if body?["code"] as? String == "P0001", let message = body?["message"] as? String {
                throw SupabaseError.rejected(message)
            }
            throw SupabaseError.server(status)
        case 401, 403:
            throw SupabaseError.denied
        default:
            throw SupabaseError.server(status)
        }
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = PostgresTime.date(from: raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                        debugDescription: "Не время: \(raw)"))
            }
            return date
        }
        return decoder
    }()
}

/// Postgres отдаёт `2026-09-27T10:11:12.123456+00:00` — с микросекундами,
/// а ISO8601DateFormatter понимает не больше миллисекунд. Дробную часть
/// приводим к трём знакам (или добавляем, если её нет).
enum PostgresTime {

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from raw: String) -> Date? {
        let pattern = /^(.+T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})?$/
        guard let match = raw.wholeMatch(of: pattern) else { return nil }
        let fraction = String(((match.2.map(String.init) ?? "") + "000").prefix(3))
        return formatter.date(from: "\(match.1).\(fraction)\(match.3.map(String.init) ?? "Z")")
    }
}
