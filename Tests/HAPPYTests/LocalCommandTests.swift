import XCTest
@testable import HAPPY

final class LocalCommandTests: XCTestCase {

    func testOpenApp() {
        XCTAssertEqual(LocalCommand.parse("open Safari"), .openApp("Safari"))
        XCTAssertEqual(LocalCommand.parse("Open System Settings"), .openApp("System Settings"))
    }

    func testOpenWebsite() {
        XCTAssertEqual(LocalCommand.parse("open github.com"), .openURL("https://github.com"))
        XCTAssertEqual(LocalCommand.parse("open https://example.com/page"), .openURL("https://example.com/page"))
    }

    func testUnsafeOpenIsRejected() {
        XCTAssertNil(LocalCommand.parse("open the pod bay doors please"))
        XCTAssertNil(LocalCommand.parse("open safari; rm -rf /"))
        XCTAssertNil(LocalCommand.parse("open $(whoami)"))
    }

    func testRememberShowForget() {
        XCTAssertEqual(LocalCommand.parse("Remember that my favorite color is blue"), .remember("my favorite color is blue"))
        XCTAssertNil(LocalCommand.parse("remember that "))
        XCTAssertEqual(LocalCommand.parse("What do you remember?"), .showMemory)
        XCTAssertEqual(LocalCommand.parse("forget everything"), .forgetAll)
    }

    func testTimeAndDate() {
        XCTAssertEqual(LocalCommand.parse("what time is it"), .time(nil))
        XCTAssertEqual(LocalCommand.parse("What's the time?"), .time(nil))
        XCTAssertEqual(LocalCommand.parse("what time is it in Tokyo?"), .time("tokyo"))
        XCTAssertEqual(LocalCommand.parse("time in new york"), .time("new york"))
        XCTAssertEqual(LocalCommand.parse("what day is it"), .date)
    }

    func testMathDetection() {
        XCTAssertEqual(LocalCommand.parse("what is 2+2?"), .math("2+2"))
        XCTAssertEqual(LocalCommand.parse("2 + 2"), .math("2 + 2"))
        XCTAssertEqual(LocalCommand.parse("calc 3 x 4"), .math("3 x 4"))
        XCTAssertNil(LocalCommand.parse("2026-10-03"))
        XCTAssertNil(LocalCommand.parse("what is love"))
    }

    func testNormalQuestionPassesThrough() {
        XCTAssertNil(LocalCommand.parse("what is the capital of France"))
        XCTAssertNil(LocalCommand.parse("explain recursion"))
    }

    func testClipboardPhrase() {
        XCTAssertTrue(LocalCommandService.mentionsClipboard("Summarize my clipboard"))
        XCTAssertFalse(LocalCommandService.mentionsClipboard("Summarize this text"))
    }
}

final class MathEvaluatorTests: XCTestCase {

    func testLongSum() {
        XCTAssertEqual(MathEvaluator.evaluate("2273 - 83984 +938839+948848"), 1805976)
    }

    func testPrecedenceAndParentheses() {
        XCTAssertEqual(MathEvaluator.evaluate("2+3*4"), 14)
        XCTAssertEqual(MathEvaluator.evaluate("2*(3+4)"), 14)
        XCTAssertEqual(MathEvaluator.evaluate("-3+5"), 2)
    }

    func testDecimalsAndDivision() {
        XCTAssertEqual(MathEvaluator.evaluate("10/4"), 2.5)
        XCTAssertEqual(MathEvaluator.evaluate("5x5"), 25)
    }

    func testInvalidInput() {
        XCTAssertNil(MathEvaluator.evaluate("1/0"))
        XCTAssertNil(MathEvaluator.evaluate("2+"))
        XCTAssertNil(MathEvaluator.evaluate("abc"))
        XCTAssertNil(MathEvaluator.evaluate("(2+3"))
    }

    func testFormat() {
        XCTAssertEqual(MathEvaluator.format(1805976), "1805976")
        XCTAssertEqual(MathEvaluator.format(2.5), "2.5")
        XCTAssertEqual(MathEvaluator.format(1.0 / 3.0), "0.3333333333")
    }
}

final class TimeZoneLookupTests: XCTestCase {

    func testCities() {
        XCTAssertEqual(TimeZoneLookup.zone(for: "tokyo")?.identifier, "Asia/Tokyo")
        XCTAssertEqual(TimeZoneLookup.zone(for: "new york")?.identifier, "America/New_York")
    }

    func testAliases() {
        XCTAssertEqual(TimeZoneLookup.zone(for: "pokhara")?.identifier, "Asia/Kathmandu")
        XCTAssertEqual(TimeZoneLookup.zone(for: "Hyderabad")?.identifier, "Asia/Kolkata")
    }

    func testUnknownPlace() {
        XCTAssertNil(TimeZoneLookup.zone(for: "atlantis"))
    }
}

final class MemoryStoreTests: XCTestCase {

    private func makeStore() -> MemoryStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("happy-memory-\(UUID().uuidString)")
            .appendingPathComponent("memory.md")
        return MemoryStore(fileURL: url)
    }

    func testStartsEmpty() {
        XCTAssertEqual(makeStore().read(), "")
    }

    func testAppendAndRead() throws {
        let store = makeStore()
        try store.append("likes tea")
        try store.append("lives somewhere warm")
        XCTAssertEqual(store.read(), "- likes tea\n- lives somewhere warm")
    }

    func testBlankFactIsIgnored() throws {
        let store = makeStore()
        try store.append("   ")
        XCTAssertEqual(store.read(), "")
    }

    func testClear() throws {
        let store = makeStore()
        try store.append("temporary")
        try store.clear()
        XCTAssertEqual(store.read(), "")
    }
}
