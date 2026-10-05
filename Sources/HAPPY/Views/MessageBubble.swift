import SwiftUI
import AppKit

struct MessageBubble: View {
    let message: ChatMessage
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tint)
                        .padding(.top, 4)
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                    if message.isStreaming && message.content.isEmpty {
                        TypingIndicatorView()
                            .padding(.vertical, 6)
                    } else if !message.content.isEmpty {
                        if message.isStreaming {
                            Text(message.content)
                                .font(.system(size: 13))
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            MarkdownContentView(markdown: message.content)
                        }
                    }

                    if let error = message.error {
                        ErrorBannerView(
                            error: error,
                            onRetry: onRetry,
                            onOpenSettings: onOpenSettings
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(bubbleBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(bubbleBorder, lineWidth: 1)
                )

                if message.role == .user {
                    // User avatar placeholder or subtle indicator
                }
            }

            // Message action footer (Copy button)
            if !message.content.isEmpty && !message.isStreaming {
                HStack(spacing: 8) {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                            Text(isCopied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(isCopied ? .green : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, message.role == .assistant ? 28 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var bubbleBackground: Color {
        if message.role == .user {
            return Color.white.opacity(0.12)
        } else {
            return Color.black.opacity(0.25)
        }
    }

    private var bubbleBorder: Color {
        if message.role == .user {
            return Color.white.opacity(0.18)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCopied = false
        }
    }
}

/// Markdown renderer supporting discrete text and fenced code blocks with language labels and copy buttons.
struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        let blocks = MarkdownBlockParser.parse(markdown)

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    InlineMarkdownView(text: text)
                case .code(let codeBlock):
                    CodeBlockView(codeBlock: codeBlock)
                }
            }
        }
    }
}

/// Renders inline markdown formatting: bold, italic, inline code, and links.
struct InlineMarkdownView: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

/// Renders a fenced code block with a dedicated header, language label, darker background,
/// monospaced font, and a Copy button that copies only the code.
struct CodeBlockView: View {
    let codeBlock: CodeBlock
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar: separate language label + Copy button
            HStack {
                Text(languageTitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isCopied ? .green : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35))

            Divider()
                .opacity(0.15)

            // Code content: monospaced font, line breaks & indentation preserved
            Text(verbatim: codeBlock.code.isEmpty ? " " : codeBlock.code)
                .font(.system(size: 12, design: .monospaced))
                .lineSpacing(3)
                .foregroundStyle(Color(nsColor: .textColor))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var languageTitle: String {
        if let language = codeBlock.language, !language.isEmpty {
            return language.lowercased()
        }
        return "text"
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeBlock.code, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCopied = false
        }
    }
}

/// Subtle pulsating typing indicator while waiting for the first token.
struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .opacity(phase == index ? 1.0 : 0.3)
                    .scaleEffect(phase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear {
            phase = 2
        }
    }
}

/// In-chat error banner with Retry and Settings actions.
struct ErrorBannerView: View {
    let error: AIError
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                if error.isMissingKey {
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
