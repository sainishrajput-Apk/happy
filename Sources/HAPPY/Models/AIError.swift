import Foundation

public enum AIError: LocalizedError, Sendable, Equatable {
    case missingAPIKey
    case network(String)
    case serverUnreachable(String)
    case rateLimited(retryAfter: TimeInterval?)
    case authentication
    case emptyResponse
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please add your API key in Settings."
        case .network(let detail):
            return "Network error: \(detail)"
        case .serverUnreachable(let message):
            return "Server unreachable: \(message). If using Ollama, ensure it is running (ollama serve)."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please retry in \(Int(seconds))s."
            }
            return "Rate limit exceeded. Please wait a moment before trying again."
        case .authentication:
            return "Authentication failed. Please verify your credentials in Settings."
        case .emptyResponse:
            return "The model returned an empty response. Please try again."
        case .invalidResponse:
            return "Received an invalid response from the server."
        }
    }

    public var isMissingKey: Bool {
        switch self {
        case .missingAPIKey, .authentication:
            return true
        default:
            return false
        }
    }
}
