import Foundation

/// Plain-text memory kept on this Mac only.
public struct MemoryStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL = MemoryStore.defaultURL) {
        self.fileURL = fileURL
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("HAPPY", isDirectory: true)
            .appendingPathComponent("memory.md")
    }

    public func read() -> String {
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func append(_ fact: String) throws {
        let cleaned = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let existing = read()
        let updated = existing.isEmpty ? "- \(cleaned)" : existing + "\n- \(cleaned)"
        try updated.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
