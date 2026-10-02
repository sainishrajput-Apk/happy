import XCTest
@testable import HAPPY

@MainActor
final class HAPPYTests: XCTestCase {

    func testMilestone1Skeleton() {
        XCTAssertTrue(true, "Milestone 1 skeleton sanity check")
    }

    func testSendMessageStreamsResponse() async {
        let expectedResponse = "Hello from HAPPY Mock!"
        let mockService = MockAIService(
            cannedResponse: expectedResponse,
            tokenDelayNanoseconds: 0
        )
        let viewModel = ChatViewModel(service: mockService)

        viewModel.sendMessage("Hi assistant")

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, "Hi assistant")
        XCTAssertEqual(viewModel.messages[1].role, .assistant)

        // Give async Task a brief moment to yield and finish
        for _ in 0..<20 {
            if !viewModel.isStreaming && !viewModel.messages[1].isStreaming {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertEqual(viewModel.messages[1].content, expectedResponse)
        XCTAssertNil(viewModel.messages[1].error)
    }

    func testStopStreamingHaltsTask() async {
        let mockService = MockAIService(
            cannedResponse: "This is a long canned response that should be cancelled early.",
            tokenDelayNanoseconds: 50_000_000 // 50ms per token
        )
        let viewModel = ChatViewModel(service: mockService)

        viewModel.sendMessage("Tell me a story")
        XCTAssertTrue(viewModel.isStreaming)

        // Let at least one token arrive
        try? await Task.sleep(nanoseconds: 70_000_000)

        viewModel.stopStreaming()

        XCTAssertFalse(viewModel.isStreaming)
        if let assistantMsg = viewModel.messages.last {
            XCTAssertFalse(assistantMsg.isStreaming)
        }
    }

    func testClearConversationResetsState() async {
        let mockService = MockAIService(cannedResponse: "Answer", tokenDelayNanoseconds: 0)
        let viewModel = ChatViewModel(service: mockService)

        viewModel.sendMessage("Question")

        for _ in 0..<10 {
            if !viewModel.isStreaming { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertFalse(viewModel.messages.isEmpty)

        viewModel.clearConversation()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testAIErrorHandlingAndRetry() async {
        let errorToInject = AIError.serverUnreachable("Ollama not running")
        let failingService = MockAIService(
            tokenDelayNanoseconds: 0,
            errorToThrow: errorToInject
        )
        let viewModel = ChatViewModel(service: failingService)

        viewModel.sendMessage("Check status")

        for _ in 0..<10 {
            if !viewModel.isStreaming { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].error, errorToInject)

        // Switch to working service and retry
        viewModel.service = MockAIService(
            cannedResponse: "Server recovered!",
            tokenDelayNanoseconds: 0
        )
        viewModel.retryLast()

        for _ in 0..<10 {
            if !viewModel.isStreaming { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].content, "Server recovered!")
        XCTAssertNil(viewModel.messages[1].error)
    }

    func testEmptyInputIgnored() {
        let mockService = MockAIService(cannedResponse: "Hello", tokenDelayNanoseconds: 0)
        let viewModel = ChatViewModel(service: mockService)

        viewModel.inputText = "   "
        viewModel.sendMessage()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testContextItemIntegration() {
        let contextItem = ContextItem(
            title: "Code snippet",
            content: "let x = 42",
            isEnabled: true
        )
        let viewModel = ChatViewModel()
        viewModel.contextItems.append(contextItem)

        XCTAssertEqual(viewModel.contextItems.count, 1)
        XCTAssertEqual(viewModel.contextItems[0].title, "Code snippet")
        XCTAssertTrue(viewModel.contextItems[0].isEnabled)
    }
}
