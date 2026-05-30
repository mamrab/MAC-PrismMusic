//
//  AudioSessionManager.swift
//  PrismMusic
//
//  Single point of `AVAudioSession` configuration. Routes audio to the
//  speakers / bluetooth / car play and keeps playing when the app is
//  backgrounded (`.playback` category + `.mixWithOthers: false`).
//

#if os(iOS)
import AVFoundation
#endif
import Foundation

final class AudioSessionManager {
    func activate() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Soft-fail. Worst case the user gets no audio routing — they'll
            // notice and we'll surface a settings prompt later.
            print("[Audio] failed to activate session: \(error)")
        }
        #endif
    }

    func deactivate() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}
