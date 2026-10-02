import Foundation

public protocol AIService: Sendable {
    func stream(messages: [ChatMessage], context: [ContextItem]) -> AsyncThrowingStream<String, Error>
}
