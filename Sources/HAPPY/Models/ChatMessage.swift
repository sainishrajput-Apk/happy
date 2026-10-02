import Foundation

public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

public struct ChatMessage: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public let timestamp: Date
    public var isStreaming: Bool
    public var error: AIError?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        error: AIError? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.error = error
    }
}
