//
//  APIClient.swift
//  PrismMusic
//
//  Networking layer talking to the PrismMusic Next.js backend. One class
//  exposes typed methods for search, recommendations, lyrics, and the
//  stream-proxy URL builder. Always pulls the current backend host and
//  Yandex token from `SettingsStore` so changes propagate immediately.
//

import Foundation
import Observation

@MainActor
final class APIClient {
    private let settings: SettingsStore
    private let session: URLSession
    private let decoder: JSONDecoder

    init(settings: SettingsStore) {
        self.settings = settings

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeoutSeconds
        config.timeoutIntervalForResource = APIConfig.timeoutSeconds * 2
        // Use the URL cache to dedupe identical recommendation / search requests
        // within a single session — saves a network round-trip on tab switches.
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 32 * 1024 * 1024)

        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Endpoints

    /// `GET /api/music/search?q=...`
    func search(query: String) async throws -> SearchResponse {
        return try await executeWithFailover(
            path: "/api/music/search",
            queryItems: [URLQueryItem(name: "q", value: query)],
            as: SearchResponse.self
        )
    }

    /// `GET /api/music/recommendations`
    func recommendations() async throws -> RecommendationsResponse {
        return try await executeWithFailover(
            path: "/api/music/recommendations",
            as: RecommendationsResponse.self
        )
    }

    /// `GET /api/music/lyrics?artist=...&title=...&id=...&duration=...`
    func lyrics(artist: String, title: String, id: String? = nil, duration: Double? = nil)
        async throws -> LyricsResponse?
    {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "title", value: title),
        ]
        if let id { items.append(URLQueryItem(name: "id", value: id)) }
        if let duration { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }

        do {
            return try await executeWithFailover(
                path: "/api/music/lyrics",
                queryItems: items,
                as: LyricsResponse.self
            )
        } catch APIError.httpStatus(let code, _) where code == 404 {
            return nil
        }
    }

    /// Builds the proxied stream URL for a given track. AVPlayer hits this
    /// URL directly; we never download the bytes ourselves.
    func streamURL(for track: Track) -> URL? {
        let trimmed = settings.backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        
        if components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        components.path += "/api/music/stream"
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "id", value: track.id),
            URLQueryItem(name: "source", value: track.source?.rawValue ?? "soundcloud"),
        ]
        if !settings.yandexToken.isEmpty {
            items.append(URLQueryItem(name: "token", value: settings.yandexToken))
        }
        components.queryItems = items
        return components.url
    }

    /// `GET /api/music/playlist?id=...&source=...` — fetches tracks for a playlist/album.
    func playlistTracks(id: String, source: String) async throws -> [Track] {
        let items = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "source", value: source),
        ]
        let response = try await executeWithFailover(
            path: "/api/music/playlist",
            queryItems: items,
            as: PlaylistDetailResponse.self
        )
        return response.tracks
    }

    /// `POST /api/music/yandex/import` — imports Yandex Liked tracks.
    func importYandexLikes(userId: String? = nil) async throws -> YandexImportResponse {
        var body: [String: Any] = [:]
        if let userId {
            body["userId"] = userId
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        var headers: [String: String] = [:]
        if !settings.yandexToken.isEmpty {
            headers["x-yandex-token"] = settings.yandexToken
        }
        
        return try await executeWithFailover(
            path: "/api/music/yandex/import",
            method: "POST",
            bodyData: bodyData,
            headers: headers,
            as: YandexImportResponse.self
        )
    }

    /// `POST /api/auth/login`
    func login(username: String, password: String) async throws -> UserResponse {
        let body = ["username": username, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await executeWithFailover(
            path: "/api/auth/login",
            method: "POST",
            bodyData: bodyData,
            as: UserResponse.self
        )
    }

    /// `POST /api/auth/register`
    func register(username: String, password: String) async throws -> UserResponse {
        let body = ["username": username, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await executeWithFailover(
            path: "/api/auth/register",
            method: "POST",
            bodyData: bodyData,
            as: UserResponse.self
        )
    }

    /// `GET /api/library/likes`
    func fetchLikedTracks(userId: String) async throws -> [Track] {
        return try await executeWithFailover(
            path: "/api/library/likes",
            queryItems: [URLQueryItem(name: "userId", value: userId)],
            as: [Track].self
        )
    }

    /// `POST /api/library/likes`
    func toggleLikeOnServer(userId: String, track: Track) async throws -> Bool {
        let trackDict: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artist": track.artist,
            "coverUrl": track.cover?.absoluteString ?? "",
            "duration": Int(track.durationSeconds ?? 0),
            "source": track.source?.rawValue ?? "unknown"
        ]
        let body: [String: Any] = [
            "userId": userId,
            "track": trackDict
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        struct LikeResponse: Decodable {
            let liked: Bool
        }
        let result = try await executeWithFailover(
            path: "/api/library/likes",
            method: "POST",
            bodyData: bodyData,
            as: LikeResponse.self
        )
        return result.liked
    }

    struct FindResponse: Decodable {
        let results: [Track]
    }

    func findTrack(title: String, artist: String, targetSource: String) async throws -> [Track] {
        let body: [String: Any] = [
            "title": title,
            "artist": artist,
            "targetSource": targetSource
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let response = try await executeWithFailover(
            path: "/api/music/find",
            method: "POST",
            bodyData: bodyData,
            as: FindResponse.self
        )
        return response.results
    }

    func replaceLikedTrack(oldTrackId: String, newTrack: Track) async throws -> Bool {
        guard settings.isLoggedIn else { return false }
        let trackDict: [String: Any] = [
            "id": newTrack.id,
            "title": newTrack.title,
            "artist": newTrack.artist,
            "coverUrl": newTrack.cover?.absoluteString ?? "",
            "duration": Int(newTrack.durationSeconds ?? 0),
            "source": newTrack.source?.rawValue ?? "unknown"
        ]
        let body: [String: Any] = [
            "userId": settings.userId,
            "oldTrackId": oldTrackId,
            "newTrack": trackDict
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        struct ReplaceResponse: Decodable {
            let success: Bool
        }
        let result = try await executeWithFailover(
            path: "/api/library/likes",
            method: "PUT",
            bodyData: bodyData,
            as: ReplaceResponse.self
        )
        return result.success
    }

    // MARK: - Failover & Request plumbing

    func rotateHost() {
        let currentHost = settings.backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextHost: String
        if let idx = APIConfig.hosts.firstIndex(of: currentHost) {
            let nextIdx = (idx + 1) % APIConfig.hosts.count
            nextHost = APIConfig.hosts[nextIdx]
        } else {
            nextHost = APIConfig.hosts[0]
        }
        settings.backendURL = nextHost
        DebugLogger.shared.append("[APIClient] Switched active host to: \(nextHost)")
    }

    private func executeWithFailover<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        bodyData: Data? = nil,
        headers: [String: String] = [:],
        as type: T.Type
    ) async throws -> T {
        var attempts = 0
        let maxAttempts = APIConfig.hosts.count
        var lastError: Error = APIError.invalidBackendURL
        
        while attempts < maxAttempts {
            let currentHost = settings.backendURL
            do {
                let components = try makeComponents(host: currentHost, path: path, queryItems: queryItems)
                guard let url = components.url else { throw APIError.invalidBackendURL }
                
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadRevalidatingCacheData
                req.httpMethod = method
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                if method == "POST" {
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                if !settings.yandexToken.isEmpty {
                    req.setValue(settings.yandexToken, forHTTPHeaderField: "x-yandex-token")
                }
                for (key, val) in headers {
                    req.setValue(val, forHTTPHeaderField: key)
                }
                if let bodyData {
                    req.httpBody = bodyData
                }
                
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                
                if http.statusCode >= 500 {
                    let preview = String(data: data.prefix(200), encoding: .utf8)
                    throw APIError.httpStatus(http.statusCode, preview)
                }
                
                guard (200..<300).contains(http.statusCode) else {
                    let bodyPreview = String(data: data.prefix(APIConfig.errorBodyLogLimit), encoding: .utf8)
                    throw APIError.httpStatus(http.statusCode, bodyPreview)
                }
                
                return try decoder.decode(T.self, from: data)
            } catch let error as APIError {
                if case .httpStatus(let status, _) = error, status < 500 {
                    throw error
                }
                lastError = error
                rotateHost()
                attempts += 1
            } catch {
                lastError = error
                rotateHost()
                attempts += 1
            }
        }
        throw lastError
    }

    private func makeComponents(host: String, path: String, queryItems: [URLQueryItem]) throws -> URLComponents {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBackendURL
        }
        if components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        components.path += path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "Некорректный URL бэкенда. Проверь Settings."
        case .invalidResponse:
            return "Сервер вернул неожиданный ответ."
        case .httpStatus(let code, _):
            return "Ошибка сервера (\(code))."
        }
    }
}
