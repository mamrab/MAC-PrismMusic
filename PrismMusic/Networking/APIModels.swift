//
//  APIModels.swift
//  PrismMusic
//
//  Response DTOs for the PrismMusic backend. Shapes mirror what the
//  Next.js routes return in `app/api/music/*`.
//

import Foundation

/// `GET /api/music/search` — returns tracks + playlists + artists.
/// Backend sends `playlists` key, not `albums`.
struct SearchResponse: Decodable, Sendable {
    let tracks: [Track]
    let albums: [Album]?

    /// The backend sometimes omits optional sections; default them to empty.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tracks = (try? container.decode([Track].self, forKey: .tracks)) ?? []

        // Backend sends playlists, not albums. Map playlists → albums.
        if let playlists = try? container.decode([SearchPlaylistDTO].self, forKey: .playlists) {
            self.albums = playlists.compactMap { p in
                Album(
                    id: p.id,
                    title: p.name ?? "Плейлист",
                    artist: p.description ?? "SoundCloud",
                    year: nil,
                    cover: p.coverUrl.flatMap { URL(string: $0) },
                    source: TrackSource(rawValue: p.source?.lowercased() ?? "soundcloud") ?? .soundcloud,
                    tracks: nil
                )
            }
        } else {
            self.albums = try? container.decode([Album].self, forKey: .albums)
        }
    }

    enum CodingKeys: String, CodingKey {
        case tracks, albums, playlists
    }
}

/// DTO for playlists in search results.
private struct SearchPlaylistDTO: Decodable, Sendable {
    let id: String
    let name: String?
    let coverUrl: String?
    let description: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, description, source
    }
}

/// `GET /api/music/recommendations` — returns playlists from SoundCloud.
///
/// Backend shape:
/// ```json
/// {
///   "title": "Подборки для вас",
///   "playlists": [
///     { "id": "...", "name": "...", "coverUrl": "...", "description": "...", "source": "soundcloud", "tracks": [] }
///   ]
/// }
/// ```
///
/// We map `playlists` → `[Album]` for display in the home grid.
struct RecommendationsResponse: Decodable, Sendable {
    let title: String?
    let albums: [Album]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try? container.decode(String.self, forKey: .title)

        // The backend returns `playlists`, each with { id, name, coverUrl, description, source, tracks }
        if let playlists = try? container.decode([PlaylistDTO].self, forKey: .playlists) {
            self.albums = playlists.map { playlist in
                Album(
                    id: playlist.id,
                    title: playlist.name,
                    artist: playlist.description ?? playlist.source ?? "SoundCloud",
                    year: nil,
                    cover: playlist.coverUrl.flatMap { URL(string: $0) },
                    source: TrackSource(rawValue: playlist.source ?? "soundcloud") ?? .soundcloud,
                    tracks: nil
                )
            }
        } else {
            // Fallback: try parsing as { tracks, albums } for forward-compat
            self.albums = (try? container.decode([Album].self, forKey: .albums)) ?? []
        }
    }

    enum CodingKeys: String, CodingKey {
        case title, playlists, albums
    }
}

/// Internal DTO matching the backend's playlist shape.
/// All fields are optional/flexible to prevent decode failures.
private struct PlaylistDTO: Decodable, Sendable {
    let id: String
    let name: String
    let coverUrl: String?
    let description: String?
    let source: String?
    let isSystem: Bool?
    // `tracks` is intentionally omitted — we don't need playlist tracks
    // from the recommendations endpoint, and including it risks decode
    // failures if the track format differs from our Track model.

    enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, description, source, isSystem
    }
}

/// `GET /api/music/lyrics` — raw LRC blob.
struct LyricsResponse: Decodable, Sendable {
    let lyrics: String?
    let source: String?
}

/// `GET /api/music/playlist?id=...&source=...` — playlist detail with tracks.
struct PlaylistDetailResponse: Decodable, Sendable {
    let id: String?
    let name: String?
    let coverUrl: String?
    let description: String?
    let tracks: [Track]
    let source: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decode(String.self, forKey: .id)
        self.name = try? container.decode(String.self, forKey: .name)
        self.coverUrl = try? container.decode(String.self, forKey: .coverUrl)
        self.description = try? container.decode(String.self, forKey: .description)
        self.tracks = (try? container.decode([Track].self, forKey: .tracks)) ?? []
        self.source = try? container.decode(String.self, forKey: .source)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, description, tracks, source
    }
}

/// `POST /api/music/yandex/import` — returns imported likes and playlists.
struct YandexImportResponse: Decodable, Sendable {
    let importedLikes: [Track]
}

/// `POST /api/auth/login` and `POST /api/auth/register` response.
struct UserResponse: Codable, Sendable {
    let id: String
    let username: String
    let token: String? // Yandex OAuth token
    let avatarUrl: String?
    let role: String?
    let createdAt: String?
}

