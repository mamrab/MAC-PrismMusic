//
//  LyricsCache.swift
//  PrismMusic
//
//  In-memory cache of parsed lyrics. Same idea as `lib/lyrics-cache.ts`
//  on the web side — keyed by track id (preferred) or artist+title hash.
//

import Foundation

/// Distinguishes "no entry in cache" from "we cached the fact that this
/// track has NO lyrics" (a confirmed 404). Both prevent extra requests
/// but yield different UI: nil → spinner, .none → "no lyrics" placeholder.
enum LyricsCacheResult {
    case parsed(ParsedLyrics)
    case noneAvailable
}

@MainActor
final class LyricsCache {
    private var store: [String: LyricsCacheResult] = [:]

    func value(for track: Track) -> ParsedLyrics? {
        guard case .parsed(let lyrics) = store[key(for: track)] else { return nil }
        return lyrics
    }

    func hasEntry(for track: Track) -> Bool {
        store[key(for: track)] != nil
    }

    func set(_ lyrics: ParsedLyrics?, for track: Track) {
        if let lyrics {
            store[key(for: track)] = .parsed(lyrics)
        } else {
            store[key(for: track)] = .noneAvailable
        }
    }

    private func key(for track: Track) -> String {
        // Track id is most stable; fall back to artist+title.
        if !track.id.isEmpty { return "id:\(track.id)" }
        return "q:\(track.artist.lowercased())|\(track.title.lowercased())"
    }
}
