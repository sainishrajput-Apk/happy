import AppKit
import Foundation

enum AppLauncher {
    /// Opens an app by name using /usr/bin/open -a (arguments are passed directly, never through a shell).
    static func open(_ name: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-a", name]
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

enum TimeZoneLookup {
    private static let aliases: [String: String] = [
        "nepal": "Asia/Kathmandu", "pokhara": "Asia/Kathmandu",
        "india": "Asia/Kolkata", "hyderabad": "Asia/Kolkata", "delhi": "Asia/Kolkata",
        "mumbai": "Asia/Kolkata", "bangalore": "Asia/Kolkata", "chennai": "Asia/Kolkata",
        "uk": "Europe/London", "japan": "Asia/Tokyo", "china": "Asia/Shanghai",
        "uae": "Asia/Dubai", "san francisco": "America/Los_Angeles", "california": "America/Los_Angeles"
    ]

    static func zone(for place: String) -> TimeZone? {
        let key = place.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ?!."))
        guard !key.isEmpty else { return nil }
        if let id = aliases[key] { return TimeZone(identifier: id) }

        let wanted = key.replacingOccurrences(of: " ", with: "_")
        let match = TimeZone.knownTimeZoneIdentifiers.first { id in
            id.split(separator: "/").last.map { $0.lowercased() == wanted } ?? false
        }
        return match.flatMap { TimeZone(identifier: $0) }
    }
}

/// Wraps any AI service: handles local commands itself, adds saved memory as background,
/// and adds clipboard text only when the user's message asks for it.
struct LocalCommandService: AIService {
    let inner: AIService
    let memory: MemoryStore

    func stream(messages: [ChatMessage], context: [ContextItem]) -> AsyncThrowingStream<String, Error> {
        let lastUser = messages.last(where: { $0.role == .user })?.content ?? ""
        if let command = LocalCommand.parse(lastUser) {
            return Self.run(command, memory: memory)
        }

        var adjusted = messages

        let profile = memory.read()
        if !profile.isEmpty, let index = adjusted.firstIndex(where: { $0.role == .user }) {
            let background = String(profile.prefix(6000))
            adjusted[index].content = "Background about the user (use only when relevant, never invent details):\n\(background)\n\nUser message:\n\(adjusted[index].content)"
        }

        if Self.mentionsClipboard(lastUser), let index = adjusted.lastIndex(where: { $0.role == .user }) {
            let clip = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shown = clip.isEmpty ? "(the clipboard is empty)" : String(clip.prefix(4000))
            adjusted[index].content += "\n\nClipboard contents (provided by the user):\n\(shown)"
        }

        return inner.stream(messages: adjusted, context: context)
    }

    static func mentionsClipboard(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("my clipboard") || lower.contains("the clipboard") || lower.contains("what i copied")
    }

    private static func run(_ command: LocalCommand, memory: MemoryStore) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                switch command {
                case .remember(let fact):
                    do {
                        try memory.append(fact)
                        continuation.yield("Saved to memory: \(fact)")
                    } catch {
                        continuation.yield("I couldn't save that: \(error.localizedDescription)")
                    }
                case .showMemory:
                    let text = memory.read()
                    if text.isEmpty {
                        continuation.yield("My memory is empty. Say \"remember that ...\" to add something.")
                    } else {
                        continuation.yield("Here is what I have saved:\n\n\(text)")
                    }
                case .forgetAll:
                    do {
                        try memory.clear()
                        continuation.yield("Memory cleared.")
                    } catch {
                        continuation.yield("I couldn't clear memory: \(error.localizedDescription)")
                    }
                case .rememberClipboard:
                    let clip = await MainActor.run {
                        NSPasteboard.general.string(forType: .string)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                    if clip.isEmpty {
                        continuation.yield("Your clipboard is empty. Copy some text first, then say \"remember my clipboard\".")
                    } else {
                        let kept = String(clip.prefix(6000))
                        do {
                            try memory.append("Saved from clipboard:\n" + kept)
                            let note = clip.count > kept.count ? " The end was cut off because it was longer than 6000 characters." : ""
                            continuation.yield("Saved \(kept.count) characters to memory." + note)
                        } catch {
                            continuation.yield("I couldn't save that: \(error.localizedDescription)")
                        }
                    }
                case .openApp(let name):
                    let opened = await AppLauncher.open(name)
                    continuation.yield(opened ? "Opening \(name)." : "I couldn't find an app named \"\(name)\".")
                case .openURL(let link):
                    if let url = URL(string: link) {
                        let opened = await MainActor.run { NSWorkspace.shared.open(url) }
                        continuation.yield(opened ? "Opening \(url.host ?? link)." : "I couldn't open that link.")
                    } else {
                        continuation.yield("I couldn't open that link.")
                    }
                case .math(let expression):
                    if let value = MathEvaluator.evaluate(expression) {
                        continuation.yield("\(expression) = **\(MathEvaluator.format(value))**")
                    } else {
                        continuation.yield("I couldn't work that out. Check the expression (for example, division by zero).")
                    }
                case .time(let place):
                    let zone = place.map { TimeZoneLookup.zone(for: $0) } ?? TimeZone.current
                    if let zone {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US")
                        formatter.timeZone = zone
                        formatter.dateFormat = "EEEE, d MMMM yyyy, h:mm a"
                        continuation.yield("\(formatter.string(from: Date())) (\(zone.identifier))")
                    } else {
                        continuation.yield("I don't know the time zone for \"\(place ?? "")\". Try a big city, like \"time in London\".")
                    }
                case .date:
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US")
                    formatter.dateFormat = "EEEE, d MMMM yyyy"
                    continuation.yield("Today is \(formatter.string(from: Date())).")
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
