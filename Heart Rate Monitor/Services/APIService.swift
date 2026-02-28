//
//  APIService.swift
//  Heart Rate Monitor
//

import Foundation

// MARK: - Notifications

extension Notification.Name {
    static let authTokenExpired = Notification.Name("authTokenExpired")
}

// MARK: - Error types

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL."
        case .invalidResponse:     return "Invalid server response."
        case .unauthorized:        return "Session expired. Please log in again."
        case .serverError(_, let msg): return msg
        case .networkError(let e): return e.localizedDescription
        case .decodingError:       return "Failed to process server response."
        }
    }
}

// MARK: - Response types

struct AuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let username: String?
    let email: String?
    let age: Int?
    let healthIssues: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType   = "token_type"
        case username, email, age
        case healthIssues = "health_issues"
    }
}

struct RegisterResponse: Codable {
    let message: String
    let username: String
}

struct UserProfileResponse: Codable {
    let username: String
    let email: String
    let age: Int?
    let healthIssues: String?

    enum CodingKeys: String, CodingKey {
        case username, email, age
        case healthIssues = "health_issues"
    }
}

struct HeartRateEntryResponse: Codable, Identifiable {
    let id: String
    let bpm: Int
    let recordedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, bpm
        case recordedAt = "recorded_at"
        case createdAt  = "created_at"
    }
}

private struct APIErrorDetail: Codable {
    let detail: String
}

// MARK: - Service

final class APIService {

    static let shared = APIService()

    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8000"
    #else
    private let baseURL = "http://172.20.10.4:8000"
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let tokenKey = "auth.accessToken"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    var isAuthenticated: Bool { token != nil }

    // MARK: Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try full ISO-8601 with fractional seconds first, then without
            let formatters: [ISO8601DateFormatter] = {
                let full = ISO8601DateFormatter()
                full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let basic = ISO8601DateFormatter()
                basic.formatOptions = [.withInternetDateTime]
                return [full, basic]
            }()
            for fmt in formatters {
                if let date = fmt.date(from: str) { return date }
            }
            // If the string lacks a timezone indicator (Z or +hh:mm/-hh:mm) after the time
            if let tIndex = str.firstIndex(of: "T") {
                let tailStart = str.index(after: tIndex)
                let tail = String(str[tailStart...])
                if !tail.contains("Z") && !tail.contains("+") && !tail.contains("-") {
                    let withZ = str + "Z"
                    for fmt in formatters {
                        if let date = fmt.date(from: withZ) { return date }
                    }
                }
            }

            // Fallback: accept ISO-like timestamps without timezone that include fractional seconds
            let fracFallbacks = ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS"]
            for pattern in fracFallbacks {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.timeZone = TimeZone(secondsFromGMT: 0)
                df.dateFormat = pattern
                if let date = df.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Cannot decode date: \(str)")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Auth

    @discardableResult
    func register(email: String, password: String) async throws -> RegisterResponse {
        let body: [String: Any] = ["email": email, "password": password]
        return try await request(.post, path: "/register", body: body)
    }

    @discardableResult
    func login(email: String, password: String) async throws -> AuthTokenResponse {
        let body: [String: Any] = ["email": email, "password": password]
        let response: AuthTokenResponse = try await request(.post, path: "/login", body: body)
        token = response.accessToken
        return response
    }

    func logout() {
        token = nil
    }

    // MARK: - Profile

    func fetchProfile() async throws -> UserProfileResponse {
        try await request(.get, path: "/me", authenticated: true)
    }

    func updateProfile(
        username: String? = nil,
        email: String? = nil,
        age: Int? = nil,
        healthIssues: String? = nil
    ) async throws -> UserProfileResponse {
        var body: [String: Any] = [:]
        if let username { body["username"] = username }
        if let email { body["email"] = email }
        if let age { body["age"] = age }
        if let healthIssues { body["health_issues"] = healthIssues }
        return try await request(.put, path: "/me", body: body, authenticated: true)
    }

    // MARK: - Heart-rate CRUD

    @discardableResult
    func createHeartRateEntry(
        id: String? = nil,
        bpm: Int,
        recordedAt: Date
    ) async throws -> HeartRateEntryResponse {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoDate = isoFormatter.string(from: recordedAt)
        var body: [String: Any] = ["bpm": bpm, "recorded_at": isoDate]
        if let id { body["id"] = id }
        return try await request(.post, path: "/heart-rate", body: body, authenticated: true)
    }

    func fetchHeartRateEntries(
        limit: Int = 5000,
        offset: Int = 0
    ) async throws -> [HeartRateEntryResponse] {
        try await request(
            .get,
            path: "/heart-rate?limit=\(limit)&offset=\(offset)",
            authenticated: true
        )
    }

    func deleteHeartRateEntry(id: String) async throws {
        try await requestNoContent(.delete, path: "/heart-rate/\(id)", authenticated: true)
    }

    func deleteHeartRateEntries(ids: [String]) async throws {
        let body: [String: Any] = ["ids": ids]
        // batch-delete returns {"deleted": N}, not 204
        let _: [String: Int] = try await request(
            .post, path: "/heart-rate/batch-delete", body: body, authenticated: true
        )
    }

    // MARK: - Internals

    private enum HTTPMethod: String {
        case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    }

    private func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        let data = try await rawRequest(method, path: path, body: body, authenticated: authenticated)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func requestNoContent(
        _ method: HTTPMethod,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = false
    ) async throws {
        _ = try await rawRequest(method, path: path, body: body, authenticated: authenticated)
    }

    private func rawRequest(
        _ method: HTTPMethod,
        path: String,
        body: [String: Any]?,
        authenticated: Bool
    ) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            token = nil
            NotificationCenter.default.post(name: .authTokenExpired, object: nil)
            throw APIError.unauthorized
        default:
            let detail = (try? decoder.decode(APIErrorDetail.self, from: data))?.detail
                ?? "Unknown error"
            throw APIError.serverError(http.statusCode, detail)
        }
    }
}
