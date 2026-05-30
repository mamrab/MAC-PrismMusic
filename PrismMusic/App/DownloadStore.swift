//
//  DownloadStore.swift
//  PrismMusic
//
//  Manages offline track downloads, tracks progress, and saves tracks locally.
//

import Foundation
import Observation
import Combine

@Observable
@MainActor
final class DownloadStore {
    private(set) var downloadedTracks: [Track] = []
    private(set) var downloadingTrackIDs: Set<String> = []
    private(set) var downloadProgress: [String: Double] = [:] // trackId -> progress (0.0 to 1.0)
    
    private let api: APIClient
    
    private let downloadsDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let dir = documentsDirectory.appendingPathComponent("PrismDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }()
    
    private var registryURL: URL {
        downloadsDirectory.appendingPathComponent("registry.json")
    }
    
    init(api: APIClient) {
        self.api = api
        loadRegistry()
    }
    
    func isDownloaded(_ trackId: String) -> Bool {
        return downloadedTracks.contains(where: { $0.id == trackId })
    }
    
    func localAudioURL(for trackId: String) -> URL? {
        let fileURL = downloadsDirectory.appendingPathComponent("\(safeId(for: trackId)).mp3")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    func localCoverURL(for trackId: String) -> URL? {
        let fileURL = downloadsDirectory.appendingPathComponent("\(safeId(for: trackId))_cover.jpg")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    private func safeId(for trackId: String) -> String {
        trackId.replacingOccurrences(of: ":", with: "_")
    }
    
    // MARK: - Downloader Methods
    
    func downloadTrack(_ track: Track) async {
        guard !isDownloaded(track.id) else { return }
        guard !downloadingTrackIDs.contains(track.id) else { return }
        
        downloadingTrackIDs.insert(track.id)
        downloadProgress[track.id] = 0.0
        
        let sId = safeId(for: track.id)
        let audioURL = downloadsDirectory.appendingPathComponent("\(sId).mp3")
        let coverURL = downloadsDirectory.appendingPathComponent("\(sId)_cover.jpg")
        
        do {
            // 1. Download cover art if available
            if let artworkURL = track.artworkURL {
                let (coverData, _) = try await URLSession.shared.data(from: artworkURL)
                try coverData.write(to: coverURL)
            }
            
            // 2. Resolve stream URL from the API client
            guard let streamURL = api.streamURL(for: track) else {
                throw NSError(domain: "DownloadStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve stream URL"])
            }
            
            // 3. Download audio file bytes with progress updates
            let (asyncBytes, response) = try await URLSession.shared.bytes(from: streamURL)
            let expectedLength = response.expectedContentLength
            var data = Data()
            if expectedLength > 0 {
                data.reserveCapacity(Int(expectedLength))
            }
            
            var lastProgressUpdate = Date()
            for try await byte in asyncBytes {
                data.append(byte)
                if expectedLength > 0 {
                    let currentProgress = Double(data.count) / Double(expectedLength)
                    if Date().timeIntervalSince(lastProgressUpdate) > 0.1 || currentProgress >= 1.0 {
                        let prog = currentProgress
                        Task { @MainActor in
                            self.downloadProgress[track.id] = prog
                        }
                        lastProgressUpdate = Date()
                    }
                }
            }
            
            // Write completed audio file to disk
            try data.write(to: audioURL)
            
            // 4. Update downloaded state and save to registry
            downloadedTracks.append(track)
            saveRegistry()
            
            print("[DownloadStore] Successfully downloaded track \(track.title)")
        } catch {
            print("[DownloadStore] Failed to download track \(track.title): \(error)")
            // Cleanup incomplete files
            try? FileManager.default.removeItem(at: audioURL)
            try? FileManager.default.removeItem(at: coverURL)
        }
        
        downloadingTrackIDs.remove(track.id)
        downloadProgress.removeValue(forKey: track.id)
    }
    
    func downloadAll(tracks: [Track]) async {
        for track in tracks {
            if !isDownloaded(track.id) {
                await downloadTrack(track)
            }
        }
    }
    
    func deleteTrack(_ track: Track) {
        let sId = safeId(for: track.id)
        let audioURL = downloadsDirectory.appendingPathComponent("\(sId).mp3")
        let coverURL = downloadsDirectory.appendingPathComponent("\(sId)_cover.jpg")
        
        try? FileManager.default.removeItem(at: audioURL)
        try? FileManager.default.removeItem(at: coverURL)
        
        downloadedTracks.removeAll(where: { $0.id == track.id })
        saveRegistry()
    }
    
    func deleteAllTracks() {
        for track in downloadedTracks {
            let sId = safeId(for: track.id)
            let audioURL = downloadsDirectory.appendingPathComponent("\(sId).mp3")
            let coverURL = downloadsDirectory.appendingPathComponent("\(sId)_cover.jpg")
            try? FileManager.default.removeItem(at: audioURL)
            try? FileManager.default.removeItem(at: coverURL)
        }
        downloadedTracks.removeAll()
        saveRegistry()
    }
    
    // MARK: - Persistence
    
    private func saveRegistry() {
        do {
            let data = try JSONEncoder().encode(downloadedTracks)
            try data.write(to: registryURL)
        } catch {
            print("[DownloadStore] Failed to save registry: \(error)")
        }
    }
    
    private func loadRegistry() {
        guard FileManager.default.fileExists(atPath: registryURL.path) else { return }
        do {
            let data = try Data(contentsOf: registryURL)
            downloadedTracks = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            print("[DownloadStore] Failed to load registry: \(error)")
        }
    }
}
