import XCTest
@testable import HAPPY

final class OllamaServiceTests: XCTestCase {

    // MARK: URL building

    func testURLDoesNotDoubleV1() {
        let url = OllamaService.chatCompletionsURL(baseURL: "http://localhost:11434/v1")
        XCTAssertEqual(url?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testURLWithTrailingSlash() {
        let url = OllamaService.chatCompletionsURL(baseURL: "http://localhost:11434/v1/")
        XCTAssertEqual(url?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testURLWithoutV1AddsIt() {
        let url = OllamaService.chatCompletionsURL(baseURL: "http://localhost:11434")
        XCTAssertEqual(url?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testURLAlreadyComplete() {
        let url = OllamaService.chatCompletionsURL(baseURL: "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(url?.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testInvalidURLReturnsNil() {
        XCTAssertNil(OllamaService.chatCompletionsURL(baseURL: "not a url"))
        XCTAssertNil(OllamaService.chatCompletionsURL(baseURL: ""))
    }

    // MARK: Stream parsing

    func testNormalStreamAndDone() throws {
        let lines = [
            #"data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"Hel"},"finish_reason":null}]}"#,
            "",
            #"data: {"choices":[{"index":0,"delta":{"content":"lo"},"finish_reason":null}]}"#,
            "",
            #"data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}"#,
            "",
            "data: [DONE]",
            ""
        ]
        var parser = OllamaStreamParser()
        let events = try parser.feed(lines.joined(separator: "\n"))
        XCTAssertEqual(events, [.delta("Hel"), .delta("lo"), .done])
    }

    func testJSONSplitAcrossTwoReads() throws {
        let json = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        let firstHalf = String(json.prefix(20))
        let secondHalf = String(json.dropFirst(20)) + "\n"
        var parser = OllamaStreamParser()
        XCTAssertEqual(try parser.feed(firstHalf), [])
        XCTAssertEqual(try parser.feed(secondHalf), [.delta("Hello")])
    }

    func testEmptyStreamProducesNoEvents() throws {
        var parser = OllamaStreamParser()
        XCTAssertEqual(try parser.feed(""), [])
        XCTAssertEqual(try parser.finish(), [])
    }

    func testMalformedChunkThrowsInvalidResponse() {
        var parser = OllamaStreamParser()
        XCTAssertThrowsError(try parser.feed("data: {not json}\n")) { error in
            XCTAssertEqual(error as? AIError, .invalidResponse)
        }
    }

    func testIgnoresCommentsAndOtherLines() throws {
        var parser = OllamaStreamParser()
        let events = try parser.feed(": keep-alive\nevent: message\n\ndata:\n")
        XCTAssertEqual(events, [])
    }

    func testStreamErrorObjectBecomesNetworkError() {
        var parser = OllamaStreamParser()
        XCTAssertThrowsError(try parser.feed(#"data: {"error":{"message":"boom"}}"# + "\n")) { error in
            XCTAssertEqual(error as? AIError, .network("boom"))
        }
    }

    // MARK: Error mapping

    func testNotFoundBodyMapsToPullMessage() {
        let body = #"{"error":{"message":"model \"llama3.2:3b\" not found, try pulling it first","type":"api_error"}}"#
        let error = OllamaErrorMapper.map(status: 404, body: body, model: "llama3.2:3b", retryAfter: nil)
        XCTAssertTrue(error.errorDescription?.contains("ollama pull llama3.2:3b") ?? false)
    }

    func testRateLimitedKeepsRetryAfter() {
        let error = OllamaErrorMapper.map(status: 429, body: "", model: "m", retryAfter: 7)
        XCTAssertEqual(error, .rateLimited(retryAfter: 7))
    }

    func testUnauthorizedMapsToAuthentication() {
        let error = OllamaErrorMapper.map(status: 401, body: "", model: "m", retryAfter: nil)
        XCTAssertEqual(error, .authentication)
    }

    func testServerErrorIncludesDetail() {
        let error = OllamaErrorMapper.map(status: 500, body: #"{"error":"out of memory"}"#, model: "m", retryAfter: nil)
        XCTAssertEqual(error, .network("Server returned HTTP 500: out of memory"))
    }

    func testConnectionRefusedMapsToServerUnreachable() {
        let error = OllamaErrorMapper.map(urlError: URLError(.cannotConnectToHost), baseURL: "http://localhost:11434/v1")
        XCTAssertEqual(error, .serverUnreachable("Could not connect to Ollama at http://localhost:11434/v1"))
    }

    // MARK: Request body

    func testRequestBodySkipsErrorAndEmptyMessages() throws {
        let messages = [
            ChatMessage(role: .user, content: "Hi"),
            ChatMessage(role: .assistant, content: "", error: .emptyResponse),
            ChatMessage(role: .assistant, content: "Hello!"),
            ChatMessage(role: .user, content: "2+2?")
        ]
        let data = try XCTUnwrap(OllamaService.makeRequestBody(model: "llama3.2:3b", messages: messages))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, "llama3.2:3b")
        XCTAssertEqual(object["stream"] as? Bool, true)
        let sent = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(sent.count, 3)
        XCTAssertEqual(sent.first?["role"], "user")
        XCTAssertEqual(sent.last?["content"], "2+2?")
    }
}
