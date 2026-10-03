import Foundation

/// Simple commands HAPPY handles itself, instantly, without calling an AI model.
public enum LocalCommand: Equatable, Sendable {
    case openApp(String)
    case openURL(String)
    case remember(String)
    case showMemory
    case forgetAll
    case time(String?)
    case date
    case math(String)

    private static let timePhrases: Set<String> = [
        "what time is it", "what time is it now", "what's the time", "whats the time",
        "what is the time", "current time", "time now", "time"
    ]
    private static let datePhrases: Set<String> = [
        "what's the date", "whats the date", "what is the date", "today's date", "todays date",
        "what is today's date", "what's today's date", "what day is it", "date"
    ]
    private static let placePrefixes = [
        "what time is it in ", "what's the time in ", "whats the time in ",
        "what is the time in ", "current time in ", "time in "
    ]

    public static func parse(_ raw: String) -> LocalCommand? {
        let text = raw
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let trimSet = CharacterSet(charactersIn: "?!. ")
        let bare = lower.trimmingCharacters(in: trimSet)

        // Memory
        for prefix in ["remember that ", "remember: "] where lower.hasPrefix(prefix) {
            let fact = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return fact.isEmpty ? nil : .remember(fact)
        }
        if ["what do you remember", "what do you remember about me", "show memory"].contains(bare) {
            return .showMemory
        }
        if ["forget everything", "clear memory", "forget all"].contains(bare) {
            return .forgetAll
        }

        // Time and date
        if timePhrases.contains(bare) { return .time(nil) }
        if datePhrases.contains(bare) { return .date }
        for prefix in placePrefixes where lower.hasPrefix(prefix) {
            let place = String(lower.dropFirst(prefix.count)).trimmingCharacters(in: trimSet)
            if !place.isEmpty, place.count <= 40 { return .time(place) }
        }

        // Math
        if let expression = mathExpression(from: lower) {
            return .math(expression)
        }

        // Open an app or a website
        if lower.hasPrefix("open ") {
            let target = String(text.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: " !"))
            if let url = normalizedURL(target) { return .openURL(url) }

            let name = target.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let words = name.split(separator: " ")
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-"))
            if !name.isEmpty,
               words.count <= 3,
               name.count <= 40,
               name.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                return .openApp(name)
            }
        }
        return nil
    }

    private static func normalizedURL(_ target: String) -> String? {
        guard !target.isEmpty, !target.contains(where: { $0.isWhitespace }) else { return nil }
        let candidate = (target.hasPrefix("http://") || target.hasPrefix("https://")) ? target : "https://" + target
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme, ["http", "https"].contains(scheme),
              let host = components.host, host.contains("."),
              host.range(of: "^[A-Za-z0-9.-]+$", options: .regularExpression) != nil else {
            return nil
        }
        return candidate
    }

    private static func mathExpression(from lower: String) -> String? {
        let trim = CharacterSet(charactersIn: "?!= ")
        var s = lower.trimmingCharacters(in: trim)
        var hadPrefix = false
        for prefix in ["what is ", "what's ", "whats ", "calculate ", "calc ", "compute "] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count)).trimmingCharacters(in: trim)
            hadPrefix = true
            break
        }
        guard !s.isEmpty, s.count <= 200 else { return nil }

        let allowed = CharacterSet(charactersIn: "0123456789+-*/x\u{00D7}\u{00F7}(). ")
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              s.contains(where: { $0.isASCII && $0.isNumber }),
              s.contains(where: { "+-*/x\u{00D7}\u{00F7}".contains($0) }) else {
            return nil
        }

        // Avoid treating dates or phone numbers like 2026-10-03 as math.
        let clearlyMath = hadPrefix
            || s.contains(where: { "*/x\u{00D7}\u{00F7}()".contains($0) })
            || s.contains(" + ")
            || s.contains(" - ")
        return clearlyMath ? s : nil
    }
}
