import Foundation

public enum ContextType: String, Codable, Sendable {
    case text
    case selection
    case clipboard
}

public struct ContextItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let type: ContextType
    public let title: String
    public let content: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        type: ContextType = .text,
        title: String,
        content: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.isEnabled = isEnabled
    }
}
