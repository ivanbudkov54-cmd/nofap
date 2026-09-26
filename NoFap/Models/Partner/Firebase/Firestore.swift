//
//  Firestore.swift
//  NoFap
//
//  Тонкий клиент Firestore REST API — ровно то, что нужно напарнику,
//  без официального SDK с его десятками мегабайт зависимостей.
//

import Foundation

enum FirestoreError: Error {
    case denied
    /// Документ уже существует или изменился с момента чтения.
    case conflict
    case server(Int)
}

enum FirestoreValue {
    case string(String)
    case int(Int)
    case time(Date)
    case null

    var json: [String: Any] {
        switch self {
        case .string(let value): ["stringValue": value]
        case .int(let value):    ["integerValue": String(value)]
        case .time(let value):   ["timestampValue": FirestoreTime.string(from: value)]
        case .null:              ["nullValue": NSNull()]
        }
    }
}

struct FirestoreDocument {
    let id: String
    let updateTime: String?
    let fields: [String: Any]

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else { return nil }
        id = String(name.split(separator: "/").last ?? "")
        updateTime = json["updateTime"] as? String
        fields = json["fields"] as? [String: Any] ?? [:]
    }

    func string(_ key: String) -> String? {
        (fields[key] as? [String: Any])?["stringValue"] as? String
    }

    func int(_ key: String) -> Int? {
        ((fields[key] as? [String: Any])?["integerValue"] as? String).flatMap(Int.init)
    }

    func date(_ key: String) -> Date? {
        ((fields[key] as? [String: Any])?["timestampValue"] as? String).flatMap(FirestoreTime.date(from:))
    }
}

/// Firestore отдаёт время с наносекундами (`…:05.123456789Z`), а
/// ISO8601DateFormatter понимает не больше миллисекунд — дробную часть
/// обрезаем до трёх знаков.
enum FirestoreTime {

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from raw: String) -> Date? {
        var text = raw
        if let dot = text.firstIndex(of: "."), let zone = text[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
            let fraction = text[text.index(after: dot)..<zone]
            text.replaceSubrange(text.index(after: dot)..<zone, with: String((fraction + "000").prefix(3)))
        } else if let zone = text.lastIndex(of: "Z") {
            text.insert(contentsOf: ".000", at: zone)
        }
        return formatter.date(from: text)
    }
}

@MainActor
final class Firestore {

    private let session: FirebaseSession

    init(session: FirebaseSession) {
        self.session = session
    }

    private var root: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents"
    }

    /// nil — документа нет.
    func get(_ path: String) async throws -> FirestoreDocument? {
        let (status, body) = try await send("GET", "\(root)/\(path)")
        if status == 404 { return nil }
        try check(status)
        return FirestoreDocument(json: body as? [String: Any] ?? [:])
    }

    /// Создаёт или обновляет. С `mask` трогает только перечисленные поля,
    /// остальные в документе остаются как были.
    func set(_ path: String,
             _ fields: [String: FirestoreValue],
             mask: [String]? = nil,
             mustNotExist: Bool = false,
             unchangedSince updateTime: String? = nil) async throws {
        var query: [URLQueryItem] = (mask ?? []).map { .init(name: "updateMask.fieldPaths", value: $0) }
        if mustNotExist { query.append(.init(name: "currentDocument.exists", value: "false")) }
        if let updateTime { query.append(.init(name: "currentDocument.updateTime", value: updateTime)) }

        let (status, _) = try await send("PATCH", "\(root)/\(path)", query: query,
                                         json: ["fields": fields.mapValues(\.json)])
        try check(status)
    }

    func delete(_ path: String) async throws {
        let (status, _) = try await send("DELETE", "\(root)/\(path)")
        if status == 404 { return }
        try check(status)
    }

    /// Создаёт документ, проставляя `serverTimeField` временем сервера, и
    /// возвращает это время. Время сервера, а не телефона: у двух людей
    /// часы расходятся, и порядок сообщений по ним поплыл бы.
    func create(_ path: String,
                _ fields: [String: FirestoreValue],
                serverTimeField: String) async throws -> Date {
        let name = "projects/\(FirebaseConfig.projectID)/databases/(default)/documents/\(path)"
        let write: [String: Any] = [
            "update": ["name": name, "fields": fields.mapValues(\.json)],
            "updateTransforms": [["fieldPath": serverTimeField, "setToServerValue": "REQUEST_TIME"]],
            "currentDocument": ["exists": false]
        ]
        let (status, body) = try await send("POST", "\(root):commit", json: ["writes": [write]])
        try check(status)

        let results = (body as? [String: Any])?["writeResults"] as? [[String: Any]]
        let transform = (results?.first?["transformResults"] as? [[String: Any]])?.first
        return (transform?["timestampValue"] as? String).flatMap(FirestoreTime.date(from:)) ?? Date()
    }

    /// Документы подколлекции `collection` у `parent`, где `field` ≥ `since`,
    /// по возрастанию. Пустой ответ стоит одно чтение, а не всю переписку.
    func documents(in parent: String,
                   collection: String,
                   orderedBy field: String,
                   since: Date?) async throws -> [FirestoreDocument] {
        var structured: [String: Any] = [
            "from": [["collectionId": collection]],
            "orderBy": [["field": ["fieldPath": field], "direction": "ASCENDING"]]
        ]
        if let since {
            structured["where"] = ["fieldFilter": [
                "field": ["fieldPath": field],
                "op": "GREATER_THAN_OR_EQUAL",
                "value": FirestoreValue.time(since).json
            ]]
        }

        let (status, body) = try await send("POST", "\(root)/\(parent):runQuery",
                                            json: ["structuredQuery": structured])
        try check(status)
        let rows = body as? [[String: Any]] ?? []
        return rows.compactMap { ($0["document"] as? [String: Any]).flatMap(FirestoreDocument.init(json:)) }
    }

    // MARK: - Внутреннее

    private func check(_ status: Int) throws {
        switch status {
        case 200..<300: return
        case 403:       throw FirestoreError.denied
        case 400, 409:  throw FirestoreError.conflict   // FAILED_PRECONDITION / ALREADY_EXISTS
        default:        throw FirestoreError.server(status)
        }
    }

    private func send(_ method: String,
                      _ url: String,
                      query: [URLQueryItem] = [],
                      json: [String: Any]? = nil,
                      isRetry: Bool = false) async throws -> (Int, Any?) {
        var components = URLComponents(string: url)!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(try await session.token())", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // Токен отозвали раньше срока — один раз берём новый и повторяем.
        if status == 401, !isRetry {
            session.invalidate()
            return try await send(method, url, query: query, json: json, isRetry: true)
        }
        return (status, data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data))
    }
}
