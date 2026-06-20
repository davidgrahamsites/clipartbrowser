import Foundation

/// Lightweight file logger for diagnosing the running app. Writes Markdown to
/// `~/Apps/ClipartBrowser/debuglog.md`. The file is truncated at app launch so it
/// always reflects the most recent session and stays compact.
enum DebugLog {
    private static let queue = DispatchQueue(label: "clipartbrowser.debuglog")

    private static let fileURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Apps/ClipartBrowser/debuglog.md")

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // Only ever read/written inside the serial `queue`, so this is safe.
    nonisolated(unsafe) private static var startedSession = false

    /// Appends a timestamped event line. Thread-safe; never throws.
    static func log(_ message: String) {
        let line = "- `\(timestamp.string(from: Date()))` \(message)\n"
        queue.async {
            if !startedSession {
                startedSession = true
                let header = """
                # ClipartBrowser Debug Log

                Session started \(ISO8601DateFormatter().string(from: Date())).
                Truncated each launch. Newest events at the bottom.

                ## Events

                """
                try? header.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        }
    }
}
