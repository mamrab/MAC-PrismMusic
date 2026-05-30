//
//  RecommendationsStore.swift
//  PrismMusic
//
//  Fetches and caches the home-screen recommendations (playlists from
//  SoundCloud, mapped to Albums). Loaded once at app start and refreshable
//  by pull-to-refresh in `HomeView`.
//

import Foundation
import Observation

@Observable
@MainActor
final class RecommendationsStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var albums: [Album] = []

    /// Fires a fetch only if we don't already have data — idempotent.
    func loadIfNeeded(client: APIClient) async {
        if case .loaded = state, !albums.isEmpty { return }
        await refresh(client: client)
    }

    func refresh(client: APIClient) async {
        state = .loading
        do {
            let response = try await client.recommendations()
            albums = response.albums
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
