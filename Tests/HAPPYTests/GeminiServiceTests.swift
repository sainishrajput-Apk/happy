import XCTest
@testable import HAPPY

final class GeminiServiceTests: XCTestCase {

    func testParsesTextFromStreamChunks() throws {
        let lines = [
            #"data: {"candidates":[{"content":{"parts":[{"text":"Hel"}],"role":"model"}}]}"#,
            "",
            #"data: {"candidates":[{"content":{"parts":[{"text":"lo"}],"role":"model"}}]}"#,
            ""
        ]
        var parser = GeminiStreamParser()
        XCTAssertEqual(try parser.feed(lines.joined(separator: "\n")), ["Hel", "lo"])
    }

    func testJSONSplitAcrossReads() throws {
        let json = #"data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}"#
        var parser = GeminiStreamParser()
        XCTAssertEqual(try parser.feed(String(json.prefix(25))), [])
        XCTAssertEqual(try parser.feed(String(json.dropFirst(25)) + "\n"), ["Hello"])
    }

    func testMalformedChunkThrows() {
        var parser = GeminiStreamParser()
        XCTAssertThrowsError(try parser.feed("data: {nope}\n")) { error in
            XCTAssertEqual(error as? AIError, .invalidResponse)
        }
    }

    func testErrorObjectThrows() {
        var parser = GeminiStreamParser()
        XCTAssertThrowsError(try parser.feed(#"data: {"error":{"message":"boom"}}"# + "\n")) { error in
            XCTAssertEqual(error as? AIError, .network("boom"))
        }
    }

    func testBlockedChunkProducesNoText() throws {
        var parser = GeminiStreamParser()
        XCTAssertEqual(try parser.feed(#"data: {"candidates":[{"finishReason":"SAFETY"}]}"# + "\n"), [])
    }

    func testStreamURLStripsModelsPrefix() {
        let url = GeminiService.streamURL(model: "models/gemini-test")
        XCTAssertEqual(url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:streamGenerateContent?alt=sse")
    }

    func testBlankModelGivesNoURL() {
        XCTAssertNil(GeminiService.streamURL(model: "  "))
    }

    func testRequestBodyMapsRolesAndSkipsSystem() throws {
        let messages = [
            ChatMessage(role: .user, content: "Hi"),
            ChatMessage(role: .assistant, content: "Hello"),
            ChatMessage(role: .system, content: "ignore me"),
            ChatMessage(role: .user, content: "2+2?")
        ]
        let data = try XCTUnwrap(GeminiService.makeRequestBody(messages: messages))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let contents = try XCTUnwrap(object["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.compactMap { $0["role"] as? String }, ["user", "model", "user"])
    }

    func testInvalidKeyMapsToAuthentication() {
        let body = #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#
        XCTAssertEqual(GeminiErrorMapper.map(status: 400, body: body, model: "m"), .authentication)
    }

    func testRateLimit() {
        XCTAssertEqual(GeminiErrorMapper.map(status: 429, body: "", model: "m"), .rateLimited(retryAfter: nil))
    }

    func testNotFoundMentionsModel() {
        let error = GeminiErrorMapper.map(status: 404, body: "", model: "my-model")
        XCTAssertTrue(error.errorDescription?.contains("my-model") ?? false)
    }
}
