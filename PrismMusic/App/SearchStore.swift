//
//  SearchStore.swift
//  PrismMusic
//
//  Debounced search query → backend → results. The UI binds the query
//  field directly; the store handles debouncing and request cancellation
//  so we don't fire one request per keystroke.
//

import Foundation
import Observation

@Observable
@MainActor
final class SearchStore {
    enum State: Equatable {
        case idle
        case searching
        case results(tracks: [Track], albums: [Album])
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Latest user-entered query, kept here so the UI can read it back
    /// (for highlighting, "no results for X" messages, etc.).
    private(set) var query: String = ""

    private var task: Task<Void, Never>?

    /// Call this on every keystroke. Cancels any in-flight request and
    /// debounces by 350ms before hitting the network.
    func update(query: String, client: APIClient) {
        self.query = query
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.state = .searching
            do {
                let response = try await client.search(query: trimmed)
                guard !Task.isCancelled else { return }
                self.state = .results(tracks: response.tracks, albums: response.albums ?? [])
            } catch is CancellationError {
                // ignore
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func clear() {
        task?.cancel()
        query = ""
        state = .idle
    }
}
