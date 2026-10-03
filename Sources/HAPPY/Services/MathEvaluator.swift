import Foundation

/// Small, safe calculator: + - * / ( ) and decimals. Returns nil for anything else.
public enum MathEvaluator {
    public static func evaluate(_ input: String) -> Double? {
        let normalized = input
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "\u{00D7}", with: "*")
            .replacingOccurrences(of: "\u{00F7}", with: "/")
            .filter { !$0.isWhitespace }
        guard !normalized.isEmpty, normalized.count <= 200 else { return nil }

        var parser = Parser(chars: Array(normalized))
        guard let value = parser.parseExpression(),
              parser.index == parser.chars.count,
              value.isFinite else {
            return nil
        }
        return value
    }

    public static func format(_ value: Double) -> String {
        String(format: "%.10g", value)
    }

    private struct Parser {
        let chars: [Character]
        var index = 0

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while index < chars.count, chars[index] == "+" || chars[index] == "-" {
                let op = chars[index]
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = (op == "+") ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }
            while index < chars.count, chars[index] == "*" || chars[index] == "/" {
                let op = chars[index]
                index += 1
                guard let rhs = parseFactor() else { return nil }
                value = (op == "*") ? value * rhs : value / rhs
            }
            return value
        }

        mutating func parseFactor() -> Double? {
            guard index < chars.count else { return nil }
            if chars[index] == "-" {
                index += 1
                return parseFactor().map { -$0 }
            }
            if chars[index] == "+" {
                index += 1
                return parseFactor()
            }
            if chars[index] == "(" {
                index += 1
                guard let value = parseExpression(), index < chars.count, chars[index] == ")" else {
                    return nil
                }
                index += 1
                return value
            }
            let start = index
            while index < chars.count, ("0"..."9").contains(chars[index]) || chars[index] == "." {
                index += 1
            }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }
    }
}
