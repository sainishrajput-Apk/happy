import Foundation
import SwiftUI

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var isStreaming: Bool = false
    @Published public var contextItems: [ContextItem] = []

    public var service: AIService
    private var streamingTask: Task<Void, Never>?
    public var serviceProvider: (@MainActor () -> AIService)?

    public init(service: AIService = MockAIService()) {
        self.service = service
    }

    /// Sends the current `inputText` or an explicitly provided prompt string.
    public func sendMessage(_ text: String? = nil) {
        let contentToSend = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contentToSend.isEmpty else { return }

        // Clear input bar
        inputText = ""

        // Append user message
        let userMessage = ChatMessage(role: .user, content: contentToSend)
        messages.append(userMessage)

        // Begin streaming response
        startStreaming()
    }

    /// Retries the last exchange if an error occurred.
    public func retryLast() {
        guard !messages.isEmpty else { return }

        // If the last message is an assistant message with an error, remove it
        if let last = messages.last, last.role == .assistant {
            messages.removeLast()
        }

        // Start streaming again for the remaining messages
        startStreaming()
    }

    /// Stops any ongoing stream.
    public func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false

        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].isStreaming = false
        }
    }

    /// Clears the entire chat history and halts streaming.
    public func clearConversation() {
        stopStreaming()
        messages.removeAll()
    }

    private func startStreaming() {
        stopStreaming()

        let assistantMessageId = UUID()
        let placeholder = ChatMessage(
            id: assistantMessageId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(placeholder)
        isStreaming = true

        let messagesSnapshot = messages.filter { $0.id != assistantMessageId }
        let contextSnapshot = contextItems.filter { $0.isEnabled }
        let currentService = serviceProvider?() ?? service

        streamingTask = Task { [weak self] in
            guard let self else { return }

            var accumulatedText = ""
            var lastFlush = Date.distantPast
            var caughtError: AIError?

            do {
                let stream = currentService.stream(messages: messagesSnapshot, context: contextSnapshot)
                for try await token in stream {
                    if Task.isCancelled { break }
                    accumulatedText += token

                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.1 {
                        lastFlush = now
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                            self.messages[idx].content = accumulatedText
                        }
                    }
                }

                if accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !Task.isCancelled {
                    caughtError = .emptyResponse
                }
            } catch let error as AIError {
                caughtError = error
            } catch {
                caughtError = .network(error.localizedDescription)
            }

            if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                self.messages[idx].content = accumulatedText
                self.messages[idx].isStreaming = false
                if let caughtError {
                    self.messages[idx].error = caughtError
                }
            }

            self.isStreaming = false
            self.streamingTask = nil
        }
    }
}
