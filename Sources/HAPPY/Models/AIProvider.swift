import Foundation

public enum AIProviderKind: String, CaseIterable, Codable, Sendable {
    case ollama = "Ollama (Local)"
    case gemini = "Google Gemini"
    case mock = "Mock Provider"

    public var isLocal: Bool {
        self == .ollama
    }

    public var requiresAPIKey: Bool {
        self == .gemini
    }
}

public struct AIProviderConfig: Codable, Sendable, Equatable {
    public var selectedProvider: AIProviderKind
    public var ollamaBaseURL: String
    public var ollamaModel: String
    public var geminiModel: String

    public static let `default` = AIProviderConfig(
        selectedProvider: .ollama,
        ollamaBaseURL: "http://localhost:11434/v1",
        ollamaModel: "llama3.2:3b",
        geminiModel: "gemini-1.5-flash"
    )

    public init(
        selectedProvider: AIProviderKind = .ollama,
        ollamaBaseURL: String = "http://localhost:11434/v1",
        ollamaModel: String = "llama3.2:3b",
        geminiModel: String = "gemini-1.5-flash"
    ) {
        self.selectedProvider = selectedProvider
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
        self.geminiModel = geminiModel
    }
}
