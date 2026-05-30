//
//  NowPlayingManager.swift
//  PrismMusic
//
//  Feeds `MPNowPlayingInfoCenter` so the lock screen, control center, car
//  play, headphones, AirPods on-head detection, and AirPlay all reflect
//  the currently playing track.
//

import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class NowPlayingManager {
    private var artworkCache: (url: URL, artwork: MPMediaItemArtwork)?

    func update(track: Track, isPlaying: Bool, progress: Double, duration: Double) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        if let album = track.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if progress.isFinite {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // Reuse cached artwork if the URL didn't change.
        if let url = track.artworkURL {
            if let cached = artworkCache, cached.url == url {
                info[MPMediaItemPropertyArtwork] = cached.artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            } else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                Task { await self.loadArtwork(from: url, into: info) }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        artworkCache = nil
    }

    private func loadArtwork(from url: URL, into info: [String: Any]) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = PlatformImage(data: data) else { return }
            let artwork = makeMediaArtwork(from: image)
            artworkCache = (url, artwork)
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
            updated[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        } catch {
            // Soft-fail; lock screen will just show the title/artist.
        }
    }
}

nonisolated private func makeMediaArtwork(from image: PlatformImage) -> MPMediaItemArtwork {
    MPMediaItemArtwork(boundsSize: image.size) { _ in image }
}
