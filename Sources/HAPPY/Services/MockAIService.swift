import Foundation

public final class MockAIService: AIService, Sendable {
    public let cannedResponse: String
    public let tokenDelayNanoseconds: UInt64
    public let errorToThrow: Error?

    public static let defaultCannedResponse = """
    Hello! I'm **HAPPY**, your native macOS assistant with *real-time* streaming.

    Here is a multi-line Swift function demonstrating async concurrency and proper indentation:

    ```swift
    func fetchAssistantGreeting(name: String) async throws -> String {
        // Simulating async work
        try await Task.sleep(nanoseconds: 50_000_000)
        return "Hello, \\(name)! HAPPY is ready to help."
    }
    ```

    Here is a second configuration block with no language tag:

    ```
    server.port = 8080
    server.host = "127.0.0.1"
    environment = "development"
    debug = true
    ```

    You can use `Cmd + Space` to summon me anytime, check the [documentation](https://apple.com), or press **Esc** to dismiss!
    """

    public init(
        cannedResponse: String = MockAIService.defaultCannedResponse,
        tokenDelayNanoseconds: UInt64 = 15_000_000,
        errorToThrow: Error? = nil
    ) {
        self.cannedResponse = cannedResponse
        self.tokenDelayNanoseconds = tokenDelayNanoseconds
        self.errorToThrow = errorToThrow
    }

    public func stream(
        messages: [ChatMessage],
        context: [ContextItem] = []
    ) -> AsyncThrowingStream<String, Error> {
        let text = cannedResponse
        let delay = tokenDelayNanoseconds
        let injectedError = errorToThrow

        return AsyncThrowingStream { continuation in
            let task = Task {
                if let injectedError {
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: delay)
                    }
                    continuation.finish(throwing: injectedError)
                    return
                }

                // Chunk into words and tokens
                let words = text.split(separator: " ", omittingEmptySubsequences: false)
                for (index, word) in words.enumerated() {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    let token = (index == words.count - 1) ? String(word) : "\(word) "
                    continuation.yield(token)

                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
