//
//  Track.swift
//  PrismMusic
//
//  Core music models, mirroring the TS types in the web app
//  (`components/music/album-card.tsx`). Custom Decodable to handle
//  backend field variations (e.g. `cover` vs `coverUrl`).
//

import Foundation
import SwiftUI

/// One playable music track.
struct Track: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let durationSeconds: Double?
    /// Cover artwork URL. Optional because some sources don't return one.
    let cover: URL?
    /// Original stream URL — passed through `/api/music/stream` for actual playback.
    let streamURL: URL?
    /// Provider tag used by the backend (`yandex`, `soundcloud`, etc).
    let source: TrackSource?

    var artworkURL: URL? {
        let safeId = id.replacingOccurrences(of: ":", with: "_")
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let docDir = paths.first {
            let localCover = docDir.appendingPathComponent("PrismDownloads/\(safeId)_cover.jpg")
            if FileManager.default.fileExists(atPath: localCover.path) {
                return localCover
            }
        }
        return proxyArtworkURL(cover)
    }

    /// Convenience: human-readable duration string (`m:ss`).
    var durationLabel: String {
        guard let d = durationSeconds, d.isFinite, d > 0 else { return "—" }
        let minutes = Int(d) / 60
        let seconds = Int(d) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album
        case durationSeconds = "duration"
        case cover, coverUrl
        case streamURL = "url"
        case audioUrl
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.album = try? container.decode(String.self, forKey: .album)
        self.durationSeconds = try? container.decode(Double.self, forKey: .durationSeconds)
        self.source = try? container.decode(TrackSource.self, forKey: .source)

        // Cover: backend sends either `cover` (URL) or `coverUrl` (string)
        if let coverURL = try? container.decode(URL.self, forKey: .cover) {
            self.cover = coverURL
        } else if let coverString = try? container.decode(String.self, forKey: .coverUrl) {
            self.cover = URL(string: coverString)
        } else if let coverString = try? container.decode(String.self, forKey: .cover) {
            self.cover = URL(string: coverString)
        } else {
            self.cover = nil
        }

        // Stream URL: backend sends either `url` or `audioUrl`
        if let url = try? container.decode(URL.self, forKey: .streamURL) {
            self.streamURL = url
        } else if let urlString = try? container.decode(String.self, forKey: .audioUrl) {
            self.streamURL = URL(string: urlString)
        } else if let urlString = try? container.decode(String.self, forKey: .streamURL) {
            self.streamURL = URL(string: urlString)
        } else {
            self.streamURL = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(streamURL, forKey: .streamURL)
        try container.encodeIfPresent(source, forKey: .source)
    }

    /// Manual init for programmatic construction (e.g. from API mapping).
    init(id: String, title: String, artist: String, album: String? = nil,
         durationSeconds: Double? = nil, cover: URL? = nil,
         streamURL: URL? = nil, source: TrackSource? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.cover = cover
        self.streamURL = streamURL
        self.source = source
    }
}

enum TrackSource: String, Codable, Sendable, CaseIterable {
    case yandex
    case soundcloud
    case spotify
    case other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        self = TrackSource(rawValue: raw) ?? .other
    }

    /// Display label (`Я.Музыка`, `SoundCloud`, ...).
    var label: String {
        switch self {
        case .yandex: "Я.Музыка"
        case .soundcloud: "SoundCloud"
        case .spotify: "Spotify"
        case .other: "Другое"
        }
    }

    var hasCustomIcon: Bool {
        self != .other
    }
}

/// An album / playlist / track-group as returned by search & recommendations.
struct Album: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let year: Int?
    let cover: URL?
    let source: TrackSource?
    let tracks: [Track]?

    var artworkURL: URL? { proxyArtworkURL(cover) }
}

/// Helper function to proxy SoundCloud artwork URLs through our Next.js backend.
func proxyArtworkURL(_ originalURL: URL?) -> URL? {
    guard let originalURL = originalURL else { return nil }
    let urlString = originalURL.absoluteString
    if urlString.contains("sndcdn.com") {
        let stored = UserDefaults.standard.string(forKey: "prism.backendURL") ?? ""
        let backend = stored.isEmpty ? "https://prism-music-virid.vercel.app" : stored
        var cleanBackend = backend.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBackend.hasSuffix("/") {
            cleanBackend.removeLast()
        }
        if let encodedUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let proxied = URL(string: "\(cleanBackend)/api/music/artwork?url=\(encodedUrl)") {
            return proxied
        }
    }
    return originalURL
}
