import XCTest
@testable import HAPPY

@MainActor
final class AIErrorHandlingTests: XCTestCase {

    // MARK: - User-Facing Message Verification for Every AIError Case

    func testMissingAPIKeyUserFacingMessage() {
        let error = AIError.missingAPIKey
        XCTAssertEqual(
            error.errorDescription,
            "API key is missing. Please add your API key in Settings."
        )
        XCTAssertTrue(error.isMissingKey)
    }

    func testNetworkErrorUserFacingMessage() {
        let error = AIError.network("The network connection was lost.")
        XCTAssertEqual(
            error.errorDescription,
            "Network error: The network connection was lost."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    func testServerUnreachableUserFacingMessage() {
        let error = AIError.serverUnreachable("Connection refused on port 11434")
        XCTAssertEqual(
            error.errorDescription,
            "Server unreachable: Connection refused on port 11434. If using Ollama, ensure it is running (ollama serve)."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    func testRateLimitedWithDurationUserFacingMessage() {
        let error = AIError.rateLimited(retryAfter: 60)
        XCTAssertEqual(
            error.errorDescription,
            "Rate limited. Please retry in 60s."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    func testRateLimitedWithoutDurationUserFacingMessage() {
        let error = AIError.rateLimited(retryAfter: nil)
        XCTAssertEqual(
            error.errorDescription,
            "Rate limit exceeded. Please wait a moment before trying again."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    func testAuthenticationErrorUserFacingMessage() {
        let error = AIError.authentication
        XCTAssertEqual(
            error.errorDescription,
            "Authentication failed. Please verify your credentials in Settings."
        )
        XCTAssertTrue(error.isMissingKey)
    }

    func testEmptyResponseUserFacingMessage() {
        let error = AIError.emptyResponse
        XCTAssertEqual(
            error.errorDescription,
            "The model returned an empty response. Please try again."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    func testInvalidResponseUserFacingMessage() {
        let error = AIError.invalidResponse
        XCTAssertEqual(
            error.errorDescription,
            "Received an invalid response from the server."
        )
        XCTAssertFalse(error.isMissingKey)
    }

    // MARK: - Retry Behavior for Every AIError Case

    private func verifyRetryBehavior(for errorToInject: AIError) async {
        let failingService = MockAIService(
            tokenDelayNanoseconds: 0,
            errorToThrow: errorToInject
        )
        let viewModel = ChatViewModel(service: failingService)

        viewModel.sendMessage("Test query for \(errorToInject)")

        // Wait for streaming task to finish with error
        for _ in 0..<15 {
            if !viewModel.isStreaming { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
        XCTAssertEqual(viewModel.messages[1].error, errorToInject)
        XCTAssertEqual(viewModel.messages[1].error?.errorDescription, errorToInject.errorDescription)

        // Now recover: switch service to working mock and trigger retryLast()
        let recoveryMessage = "Recovered after \(errorToInject)"
        viewModel.service = MockAIService(
            cannedResponse: recoveryMessage,
            tokenDelayNanoseconds: 0
        )
        viewModel.retryLast()

        // Wait for retry streaming to complete
        for _ in 0..<15 {
            if !viewModel.isStreaming { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
        XCTAssertNil(viewModel.messages[1].error)
        XCTAssertEqual(viewModel.messages[1].content, recoveryMessage)
    }

    func testRetryMissingAPIKey() async {
        await verifyRetryBehavior(for: .missingAPIKey)
    }

    func testRetryNetworkError() async {
        await verifyRetryBehavior(for: .network("Timeout"))
    }

    func testRetryServerUnreachable() async {
        await verifyRetryBehavior(for: .serverUnreachable("ollama serve not found"))
    }

    func testRetryRateLimitedWithDuration() async {
        await verifyRetryBehavior(for: .rateLimited(retryAfter: 30))
    }

    func testRetryRateLimitedWithoutDuration() async {
        await verifyRetryBehavior(for: .rateLimited(retryAfter: nil))
    }

    func testRetryAuthentication() async {
        await verifyRetryBehavior(for: .authentication)
    }

    func testRetryEmptyResponse() async {
        await verifyRetryBehavior(for: .emptyResponse)
    }

    func testRetryInvalidResponse() async {
        await verifyRetryBehavior(for: .invalidResponse)
    }
}
