import Foundation

private struct GeminiChunk: Decodable {
    struct Part: Decodable { let text: String? }
    struct Content: Decodable { let parts: [Part]? }
    struct Candidate: Decodable { let content: Content? }
    struct APIError: Decodable { let message: String? }
    let candidates: [Candidate]?
    let error: APIError?
}

/// Turns Gemini server-sent-event text into text pieces. Handles data split across reads.
public struct GeminiStreamParser: Sendable {
    private var buffer = ""

    public init() {}

    public mutating func feed(_ chunk: String) throws -> [String] {
        buffer += chunk
        var texts: [String] = []
        while let index = buffer.firstIndex(where: { $0.isNewline }) {
            let line = String(buffer[buffer.startIndex..<index])
            buffer.removeSubrange(buffer.startIndex...index)
            if let text = try Self.parse(line: line) {
                texts.append(text)
            }
        }
        return texts
    }

    public mutating func finish() throws -> [String] {
        let remaining = buffer
        buffer = ""
        if let text = try Self.parse(line: remaining) {
            return [text]
        }
        return []
    }

    static func parse(line raw: String) throws -> String? {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty { return nil }

        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(GeminiChunk.self, from: data) else {
            throw AIError.invalidResponse
        }
        if let apiError = chunk.error {
            throw AIError.network(apiError.message ?? "The server reported an error")
        }
        let text = (chunk.candidates?.first?.content?.parts ?? [])
            .compactMap { $0.text }
            .joined()
        return text.isEmpty ? nil : text
    }
}

enum GeminiErrorMapper {
    static func map(status: Int, body: String, model: String) -> AIError {
        let detail = OllamaErrorMapper.extractMessage(from: body)
        switch status {
        case 400:
            if body.contains("API_KEY_INVALID") || body.contains("API key not valid") {
                return .authentication
            }
            return .network("Gemini rejected the request: \(detail ?? "bad request")")
        case 401, 403:
            return .authentication
        case 404:
            return .network("Model \"\(model)\" was not found. Check the Gemini model name in Settings.")
        case 429:
            return .rateLimited(retryAfter: nil)
        default:
            if let detail {
                return .network("Gemini returned HTTP \(status): \(detail)")
            }
            return .network("Gemini returned HTTP \(status)")
        }
    }
}

public struct GeminiService: AIService {
    public let apiKey: String
    public let model: String
    private let session: URLSession

    public init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    static func streamURL(model: String) -> URL? {
        var name = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("models/") { name.removeFirst("models/".count) }
        guard !name.isEmpty else { return nil }
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(name):streamGenerateContent?alt=sse")
    }

    static func makeRequestBody(messages: [ChatMessage]) -> Data? {
        struct Body: Encodable {
            struct Part: Encodable { let text: String }
            struct Content: Encodable {
                let role: String
                let parts: [Part]
            }
            let contents: [Content]
        }
        let contents = messages
            .filter { $0.error == nil && !$0.content.isEmpty && $0.role != .system }
            .map { Body.Content(role: $0.role == .assistant ? "model" : "user", parts: [Body.Part(text: $0.content)]) }
        guard !contents.isEmpty else { return nil }
        return try? JSONEncoder().encode(Body(contents: contents))
    }

    public func stream(messages: [ChatMessage], context: [ContextItem]) -> AsyncThrowingStream<String, Error> {
        let apiKey = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = self.model
        let session = self.session
        let payload = Self.makeRequestBody(messages: messages)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
                    guard let url = Self.streamURL(model: model) else {
                        throw AIError.network("The Gemini model name \"\(model)\" is not valid. Check it in Settings.")
                    }
                    guard let payload else { throw AIError.invalidResponse }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                    request.timeoutInterval = 60
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
                        throw GeminiErrorMapper.map(status: http.statusCode, body: body, model: model)
                    }

                    var parser = GeminiStreamParser()
                    var receivedText = false

                    for try await line in bytes.lines {
                        for text in try parser.feed(line + "\n") {
                            receivedText = true
                            continuation.yield(text)
                        }
                    }
                    for text in try parser.finish() {
                        receivedText = true
                        continuation.yield(text)
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
                        continuation.finish(throwing: AIError.network(error.localizedDescription))
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
