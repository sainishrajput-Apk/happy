import Foundation

// MARK: - Stream events and parser

public enum OllamaStreamEvent: Equatable, Sendable {
    case delta(String)
    case done
}

private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta?
    }
    struct StreamError: Decodable { let message: String? }
    let choices: [Choice]?
    let error: StreamError?
}

/// Turns raw server-sent-event text into events. Handles data split across reads.
public struct OllamaStreamParser: Sendable {
    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: String) throws -> [OllamaStreamEvent] {
        buffer += chunk
        var events: [OllamaStreamEvent] = []
        while let index = buffer.firstIndex(where: { $0.isNewline }) {
            let line = String(buffer[buffer.startIndex..<index])
            buffer.removeSubrange(buffer.startIndex...index)
            if let event = try Self.parse(line: line) {
                events.append(event)
            }
        }
        return events
    }

    public mutating func finish() throws -> [OllamaStreamEvent] {
        let remaining = buffer
        buffer = ""
        if let event = try Self.parse(line: remaining) {
            return [event]
        }
        return []
    }

    static func parse(line raw: String) throws -> OllamaStreamEvent? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty { return nil }
        if payload == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else {
            throw AIError.invalidResponse
        }
        if let streamError = chunk.error {
            throw AIError.network(streamError.message ?? "The server reported an error")
        }
        guard let text = chunk.choices?.first?.delta?.content, !text.isEmpty else {
            return nil
        }
        return .delta(text)
    }
}

// MARK: - Error mapping

enum OllamaErrorMapper {
    static func map(status: Int, body: String, model: String, retryAfter: TimeInterval?) -> AIError {
        switch status {
        case 401, 403:
            return .authentication
        case 404:
            return .network("Model \"\(model)\" was not found. Run: ollama pull \(model) (or check the endpoint URL in Settings)")
        case 429:
            return .rateLimited(retryAfter: retryAfter)
        default:
            if let detail = extractMessage(from: body) {
                return .network("Server returned HTTP \(status): \(detail)")
            }
            return .network("Server returned HTTP \(status)")
        }
    }

    static func map(urlError: URLError, baseURL: String) -> AIError {
        switch urlError.code {
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .timedOut, .networkConnectionLost:
            return .serverUnreachable("Could not connect to Ollama at \(baseURL)")
        default:
            return .network(urlError.localizedDescription)
        }
    }

    static func extractMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = object["error"] as? String {
            return message
        }
        return nil
    }
}

// MARK: - Service

public struct OllamaService: AIService {
    public let baseURL: String
    public let model: String
    private let session: URLSession

    public init(
        baseURL: String = "http://localhost:11434/v1",
        model: String = "llama3.2:3b",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    /// Builds <base>/chat/completions without ever doubling /v1.
    static func chatCompletionsURL(baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme != nil,
              components.host != nil else {
            return nil
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.isEmpty { path = "/v1" }
        if !path.hasSuffix("/chat/completions") { path += "/chat/completions" }
        components.path = path
        return components.url
    }

    static func makeRequestBody(model: String, messages: [ChatMessage]) -> Data? {
        struct Body: Encodable {
            struct Message: Encodable {
                let role: String
                let content: String
            }
            let model: String
            let stream: Bool
            let messages: [Message]
        }
        let usable = messages
            .filter { $0.error == nil && !$0.content.isEmpty }
            .map { Body.Message(role: $0.role.rawValue, content: $0.content) }
        return try? JSONEncoder().encode(Body(model: model, stream: true, messages: usable))
    }

    public func stream(messages: [ChatMessage], context: [ContextItem]) -> AsyncThrowingStream<String, Error> {
        let baseURL = self.baseURL
        let model = self.model
        let session = self.session
        let payload = Self.makeRequestBody(model: model, messages: messages)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = Self.chatCompletionsURL(baseURL: baseURL) else {
                        throw AIError.serverUnreachable("The Ollama URL \"\(baseURL)\" is not valid")
                    }
                    guard let payload else { throw AIError.invalidResponse }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 120
                    request.httpBody = payload

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIError.invalidResponse
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line + "\n"
                            if body.count > 4000 { break }
                        }
                        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                        throw OllamaErrorMapper.map(
                            status: http.statusCode,
                            body: body,
                            model: model,
                            retryAfter: retryAfter
                        )
                    }

                    var parser = OllamaStreamParser()
                    var receivedText = false
                    var finished = false

                    lines: for try await line in bytes.lines {
                        for event in try parser.feed(line + "\n") {
                            switch event {
                            case .delta(let text):
                                receivedText = true
                                continuation.yield(text)
                            case .done:
                                finished = true
                            }
                        }
                        if finished { break lines }
                    }

                    if !finished {
                        for event in try parser.finish() {
                            if case .delta(let text) = event {
                                receivedText = true
                                continuation.yield(text)
                            }
                        }
                    }

                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }
                    if !receivedText { throw AIError.emptyResponse }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as AIError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    if error.code == .cancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: OllamaErrorMapper.map(urlError: error, baseURL: baseURL))
                    }
                } catch {
                    continuation.finish(throwing: AIError.network(error.localizedDescription))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Provider selection

/// Used for providers that aren't built yet, so the user sees a clear message.
public struct FailingAIService: AIService {
    public let error: AIError

    public init(error: AIError) {
        self.error = error
    }

    public func stream(messages: [ChatMessage], context: [ContextItem]) -> AsyncThrowingStream<String, Error> {
        let error = self.error
        return AsyncThrowingStream { $0.finish(throwing: error) }
    }
}

@MainActor
public enum AIServiceFactory {
    public static func makeService(settings: SettingsViewModel) -> AIService {
        switch settings.selectedProvider {
        case .ollama:
            return OllamaService(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
        case .mock:
            return MockAIService()
        case .gemini:
            return FailingAIService(error: .network("Gemini support has not been added yet. Choose Ollama in Settings."))
        }
    }
}
