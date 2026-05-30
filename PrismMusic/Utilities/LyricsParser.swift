//
//  LyricsParser.swift
//  PrismMusic
//
//  Parses LRC (`[mm:ss.xx] line`) and LRCX (`<mm:ss.xx> word`) timestamp
//  formats. Word-by-word timing is supported when the source contains <…>
//  per-word markers; otherwise we synthesize word timing by linear
//  distribution across the line's duration (same algorithm as
//  `components/music/synced-lyrics.tsx`).
//

import Foundation

enum LyricsParser {
    static func parse(_ raw: String, duration: Double? = nil) -> ParsedLyrics {
        // Strip metadata header tags ([ar:Artist], [ti:Title], etc.) but
        // honour the global `[offset:N]` shift (milliseconds).
        let offset = extractOffset(raw)
        let tsRegex = try! NSRegularExpression(
            pattern: #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#
        )
        let wordRegex = try! NSRegularExpression(
            pattern: #"<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>"#
        )
        let metaRegex = try! NSRegularExpression(
            pattern: #"^\[(ti|ar|al|au|by|re|ve|length|offset|id|tool|hash):"#,
            options: [.caseInsensitive]
        )

        var lines: [LyricsLine] = []
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if metaRegex.firstMatch(
                in: line,
                range: NSRange(location: 0, length: line.utf16.count)
            ) != nil { continue }

            // Find all line-level timestamps; one LRC line can carry multiple
            // (a chorus repeated at several timestamps).
            let tsMatches = tsRegex.matches(in: line, range: NSRange(location: 0, length: line.utf16.count))
            if tsMatches.isEmpty { continue }

            // The lyric body is whatever follows the LAST line-level timestamp.
            let lastTS = tsMatches.last!
            guard let lastRange = Range(lastTS.range, in: line) else { continue }
            var body = String(line[lastRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Clean up empty parens and brackets:
            body = body.replacingOccurrences(of: "\\(\\s*\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\[\\s*\\]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // Get first timestamp without offset to pass to parseWords (for prefix)
            let baseTimeWithoutOffset = decodeTimestamp(tsMatches[0], in: line, offset: 0) ?? 0.0

            // Optionally extract word-level timestamps from the body.
            let (cleanText, words) = parseWords(body: body, regex: wordRegex, firstLineTimestampWithoutOffset: baseTimeWithoutOffset)

            let baseTime = decodeTimestamp(tsMatches[0], in: line, offset: offset) ?? 0.0
            for tsMatch in tsMatches {
                guard let t = decodeTimestamp(tsMatch, in: line, offset: offset) else { continue }
                let baseShift = t - baseTime
                let adjustedWords = words.isEmpty ? nil : words.map { word in
                    // For repeated timestamps we copy the words but anchor them
                    // to this line's start instead of the first occurrence. Also add offset.
                    LyricsWord(time: word.time + offset + baseShift, text: word.text)
                }
                lines.append(LyricsLine(
                    time: t,
                    endTime: nil,
                    text: cleanText,
                    words: adjustedWords
                ))
            }
        }

        // Sort by time defensively
        var sorted = lines.sorted { $0.time < $1.time }
        for i in sorted.indices {
            let endTime = i + 1 < sorted.count ? sorted[i + 1].time : nil
            sorted[i] = LyricsLine(
                time: sorted[i].time,
                endTime: endTime,
                text: sorted[i].text,
                words: sorted[i].words ?? synthesizeWords(
                    text: sorted[i].text,
                    start: sorted[i].time,
                    end: endTime ?? (sorted[i].time + 4)
                )
            )
        }

        var linesWithPauses: [LyricsLine] = []
        let pauseThreshold = 4.0

        let syncedLines = sorted.filter { $0.time >= 0 }
        let unsyncedLines = sorted.filter { $0.time < 0 }

        if !syncedLines.isEmpty {
            // 1. Intro pause
            let firstLine = syncedLines[0]
            if firstLine.time > 5.0 {
                linesWithPauses.append(LyricsLine(
                    time: 0,
                    endTime: firstLine.time - 1.0,
                    text: "...",
                    words: nil,
                    isPause: true
                ))
            }

            // 2. Middle pauses
            for i in 0..<syncedLines.count {
                let line = syncedLines[i]
                linesWithPauses.append(line)

                if i + 1 < syncedLines.count {
                    let nextLine = syncedLines[i + 1]
                    var singingEndTime = line.time
                    if let words = line.words, !words.isEmpty {
                        let lastWord = words[words.count - 1]
                        let lastWordDur = min(1.5, (line.endTime ?? (lastWord.time + 1.5)) - lastWord.time)
                        singingEndTime = lastWord.time + lastWordDur
                    } else {
                        singingEndTime = line.endTime ?? (line.time + 4.0)
                    }

                    let gap = nextLine.time - singingEndTime
                    if gap >= pauseThreshold {
                        linesWithPauses.append(LyricsLine(
                            time: singingEndTime + 0.5,
                            endTime: nextLine.time - 1.0,
                            text: "...",
                            words: nil,
                            isPause: true
                        ))
                    }
                }
            }

            // 3. Outro pause
            if let duration = duration, duration > 0 {
                let lastLine = syncedLines[syncedLines.count - 1]
                var singingEndTime = lastLine.time
                if let words = lastLine.words, !words.isEmpty {
                    let lastWord = words[words.count - 1]
                    let lastWordDur = min(1.5, (lastLine.endTime ?? (lastWord.time + 1.5)) - lastWord.time)
                    singingEndTime = lastWord.time + lastWordDur
                } else {
                    singingEndTime = lastLine.endTime ?? (lastLine.time + 4.0)
                }

                if duration - singingEndTime >= 5.0 {
                    linesWithPauses.append(LyricsLine(
                        time: singingEndTime + 0.5,
                        endTime: duration - 1.0,
                        text: "...",
                        words: nil,
                        isPause: true
                    ))
                }
            }
        } else {
            linesWithPauses.append(contentsOf: unsyncedLines)
        }

        // Keep final lines sorted
        let finalLines = linesWithPauses.sorted { $0.time < $1.time }
        return ParsedLyrics(lines: finalLines)
    }

    // MARK: - Helpers

    private static func extractOffset(_ raw: String) -> Double {
        let regex = try! NSRegularExpression(pattern: #"\[offset:\s*(-?\d+)\s*\]"#, options: [.caseInsensitive])
        let nsRaw = raw as NSString
        guard let match = regex.firstMatch(in: raw, range: NSRange(location: 0, length: nsRaw.length)),
              match.numberOfRanges > 1
        else { return 0 }
        let valueRange = match.range(at: 1)
        let value = nsRaw.substring(with: valueRange)
        return (Double(value) ?? 0) / 1000.0
    }

    private static func decodeTimestamp(_ match: NSTextCheckingResult, in line: String, offset: Double) -> Double? {
        let nsLine = line as NSString
        guard match.numberOfRanges >= 3 else { return nil }
        let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
        let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
        var fraction: Double = 0
        if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound {
            let raw = nsLine.substring(with: match.range(at: 3))
            // 1, 2, or 3 digits — pad to 3 then divide.
            let padded = raw.padding(toLength: 3, withPad: "0", startingAt: 0)
            fraction = (Double(padded) ?? 0) / 1000.0
        }
        return minutes * 60 + seconds + fraction + offset
    }

    private static func parseWords(body: String, regex: NSRegularExpression, firstLineTimestampWithoutOffset: Double) -> (String, [LyricsWord]) {
        let nsBody = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length))
        
        var words: [LyricsWord] = []
        var cleanText = body
        
        if body.contains("<") {
            if let firstMatch = matches.first {
                let firstTagIdx = firstMatch.range.location
                if firstTagIdx > 0 {
                    let prefix = nsBody.substring(with: NSRange(location: 0, length: firstTagIdx)).trimmingCharacters(in: .whitespaces)
                    if !prefix.isEmpty {
                        let cleanPrefix = prefix.replacingOccurrences(of: "\\(\\s*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                        if !cleanPrefix.isEmpty {
                            words.append(LyricsWord(time: firstLineTimestampWithoutOffset, text: cleanPrefix))
                        }
                    }
                }
            }

            for (i, match) in matches.enumerated() {
                let minutes = Double(nsBody.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(nsBody.substring(with: match.range(at: 2))) ?? 0
                var fraction: Double = 0
                if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound {
                    let raw = nsBody.substring(with: match.range(at: 3))
                    let padded = raw.padding(toLength: 3, withPad: "0", startingAt: 0)
                    fraction = (Double(padded) ?? 0) / 1000.0
                }
                let time = minutes * 60 + seconds + fraction

                let textStart = match.range.location + match.range.length
                let textEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsBody.length
                let text = nsBody.substring(with: NSRange(location: textStart, length: max(0, textEnd - textStart)))
                    .trimmingCharacters(in: .whitespaces)
                let cleanWText = text.replacingOccurrences(of: "\\(\\s*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if !cleanWText.isEmpty {
                    words.append(LyricsWord(time: time, text: cleanWText))
                }
            }
        }
        
        // Strip <…> markers from the clean version of the text.
        cleanText = regex.stringByReplacingMatches(
            in: body,
            range: NSRange(location: 0, length: nsBody.length),
            withTemplate: ""
        ).replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        return (cleanText, words)
    }

    /// When the LRC source has only line-level timing, distribute words
    /// across the line's duration proportionally using the website's weighted algorithm.
    private static func synthesizeWords(text: String, start: Double, end: Double) -> [LyricsWord]? {
        let rawWords = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if rawWords.isEmpty { return nil }

        // Compute weights
        let weights = rawWords.map { w -> Double in
            let lettersCount = w.folding(options: .diacriticInsensitive, locale: nil)
                .filter { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("а"..."я").contains($0) || ("А"..."Я").contains($0) || $0 == "ё" || $0 == "Ё" }
                .count
            let letters = Double(lettersCount > 0 ? lettersCount : 1)
            var weight = sqrt(letters)
            
            if let lastChar = w.last {
                let lastStr = String(lastChar)
                if lastStr == "." || lastStr == "!" || lastStr == "?" || lastStr == "…" {
                    weight += 0.6
                } else if lastStr == "," || lastStr == ";" || lastStr == ":" || lastStr == "—" || lastStr == "–" || lastStr == "-" {
                    weight += 0.3
                }
            }
            return weight
        }

        let totalWeight = weights.reduce(0.0, +)
        let gap = end - start
        
        let baseSingingDur = Double(rawWords.count) * 0.45
        let maxSingingDur = Double(rawWords.count) * 0.55 + 1.2
        let singingGap = min(
            maxSingingDur,
            gap * 0.75,
            max(gap * 0.4, baseSingingDur)
        )

        let durPerUnitWeight = totalWeight > 0 ? (singingGap / totalWeight) : 0.0

        var synthesizedWords: [LyricsWord] = []
        var currentStartTime = start

        for wIdx in 0..<rawWords.count {
            let wText = rawWords[wIdx]
            let baseDur = weights[wIdx] * durPerUnitWeight
            
            // Deterministic jitter from word position (avoids hydration/re-render mismatch)
            let timeMs = Int(start.isFinite ? (start * 1000.0) : 0.0)
            let seed = abs((wIdx * 131 + timeMs) % 1000)
            let jitter = 1.0 + (((Double(seed) / 1000.0) * 0.3) - 0.15)
            let finalDur = baseDur * jitter

            synthesizedWords.append(LyricsWord(time: currentStartTime, text: wText))
            currentStartTime += finalDur
        }

        return synthesizedWords
    }
}

