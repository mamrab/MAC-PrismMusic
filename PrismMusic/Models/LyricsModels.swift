//
//  LyricsModels.swift
//  PrismMusic
//
//  Parsed structure for synchronized lyrics (LRC / LRCX). The parser lives
//  in `Utilities/LyricsParser.swift`; this file is just the data shape.
//

import Foundation

/// One word inside a synced line. Time is absolute (seconds from track start).
struct LyricsWord: Hashable, Sendable {
    let time: Double
    let text: String
}

/// One line of lyrics. `time == -1` means the line is decorative / not synced.
struct LyricsLine: Hashable, Identifiable, Sendable {
    let id = UUID()
    let time: Double
    let endTime: Double?
    let text: String
    let words: [LyricsWord]?
    let isPause: Bool

    /// Whether this line carries word-level timing.
    var hasWords: Bool { !(words?.isEmpty ?? true) }

    /// Convenience: total duration of this line (next line's time - own time
    /// works for the renderer, but a stored endTime is also honoured).
    var duration: Double? {
        guard let end = endTime, end > time else { return nil }
        return end - time
    }

    init(time: Double, endTime: Double?, text: String, words: [LyricsWord]?, isPause: Bool = false) {
        self.time = time
        self.endTime = endTime
        self.text = text
        self.words = words
        self.isPause = isPause
    }
}

/// Result of parsing a raw LRC blob.
struct ParsedLyrics: Hashable, Sendable {
    let lines: [LyricsLine]
    /// Convenience flag: are any lines actually synced (time >= 0)?
    var isSynced: Bool { lines.contains { $0.time >= 0 } }
}
