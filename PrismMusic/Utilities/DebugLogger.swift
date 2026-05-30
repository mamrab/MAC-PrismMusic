import Foundation

final class DebugLogger: @unchecked Sendable {
    static let shared = DebugLogger()
    
    private let logPath: String
    
    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logPath = dir.appendingPathComponent("debug_console.log").path
        
        // Truncate if too big (> 1MB)
        if let attr = try? FileManager.default.attributesOfItem(atPath: logPath),
           let size = attr[.size] as? UInt64, size > 1_000_000 {
            try? FileManager.default.removeItem(atPath: logPath)
        }
    }
    
    func start() {
        append("--- Debug Logger Started ---")
    }
    
    func append(_ message: String) {
        print(message)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = formatter.string(from: Date())
        let line = "[\(dateStr)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } else {
                try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    func readLogs() -> String {
        (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? "Log is empty or unreadable."
    }
    
    func clearLogs() {
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}
