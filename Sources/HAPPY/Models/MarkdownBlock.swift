import Foundation

/// Represents a parsed fenced code block.
public struct CodeBlock: Equatable, Sendable {
    public let language: String?
    public let code: String
    public let isComplete: Bool

    public init(language: String?, code: String, isComplete: Bool = true) {
        let trimmedLang = language?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.language = (trimmedLang?.isEmpty == false) ? trimmedLang : nil
        self.code = code
        self.isComplete = isComplete
    }
}

/// Represents either a standard text block (with inline markdown) or a fenced code block.
public enum MarkdownBlock: Equatable, Sendable {
    case text(String)
    case code(CodeBlock)
}

/// Parses raw markdown strings into discrete blocks of text and fenced code blocks.
/// Handles unclosed code blocks during streaming gracefully without layout jumps.
public enum MarkdownBlockParser {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        if markdown.isEmpty {
            return []
        }

        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var textLines: [String] = []
        var inCodeBlock = false
        var codeLanguage: String? = nil
        var codeLines: [String] = []

        func flushText() {
            if !textLines.isEmpty {
                let content = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    blocks.append(.text(content))
                }
                textLines.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let backtickCount = trimmed.prefix(while: { $0 == "`" }).count

            if !inCodeBlock {
                if backtickCount >= 3 {
                    let afterBackticks = trimmed.drop(while: { $0 == "`" })
                    // Check if it opens and closes on the same line (e.g. ```swift``` or ``````)
                    if afterBackticks.hasSuffix("```") && afterBackticks.count >= 3 {
                        flushText()
                        let content = afterBackticks.dropLast(3).trimmingCharacters(in: .whitespaces)
                        let lang = content.components(separatedBy: .whitespaces).first
                        blocks.append(.code(CodeBlock(language: lang?.isEmpty == false ? lang : nil, code: "", isComplete: true)))
                    } else {
                        flushText()
                        inCodeBlock = true
                        let rawLang = afterBackticks.trimmingCharacters(in: .whitespaces)
                        let lang = rawLang.components(separatedBy: .whitespaces).first
                        codeLanguage = lang?.isEmpty == false ? lang : nil
                        codeLines.removeAll()
                    }
                } else {
                    textLines.append(line)
                }
            } else {
                // Inside code block: check for closing fence (3+ backticks only)
                if backtickCount >= 3 && trimmed.allSatisfy({ $0 == "`" }) {
                    inCodeBlock = false
                    let code = codeLines.joined(separator: "\n")
                    blocks.append(.code(CodeBlock(language: codeLanguage, code: code, isComplete: true)))
                    codeLanguage = nil
                    codeLines.removeAll()
                } else {
                    codeLines.append(line)
                }
            }
        }

        if inCodeBlock {
            // Unclosed code block while streaming or unfinished
            let code = codeLines.joined(separator: "\n")
            blocks.append(.code(CodeBlock(language: codeLanguage, code: code, isComplete: false)))
        } else {
            flushText()
        }

        return blocks
    }
}
