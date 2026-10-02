import XCTest
@testable import HAPPY

final class MarkdownBlockParserTests: XCTestCase {

    // 1. No code block
    func testNoCodeBlock() {
        let markdown = "Hello **world**, this is *italic*, `inline_code`, and [link](https://apple.com)."
        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        guard case .text(let text) = blocks.first else {
            XCTFail("Expected .text block but got \(String(describing: blocks.first))")
            return
        }
        XCTAssertEqual(text, markdown)
    }

    // 2. One block with a language
    func testOneBlockWithLanguage() {
        let markdown = """
        Here is a Swift function:
        ```swift
        func greet() -> String {
            return "Hello from HAPPY"
        }
        ```
        Hope you like it!
        """
        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(blocks.count, 3)

        // Block 0: Intro text
        XCTAssertEqual(blocks[0], .text("Here is a Swift function:"))

        // Block 1: Swift code block
        let expectedCode = """
        func greet() -> String {
            return "Hello from HAPPY"
        }
        """
        XCTAssertEqual(
            blocks[1],
            .code(CodeBlock(language: "swift", code: expectedCode, isComplete: true))
        )

        // Block 2: Trailing text
        XCTAssertEqual(blocks[2], .text("Hope you like it!"))
    }

    // 3. One block without a language
    func testOneBlockWithoutLanguage() {
        let markdown = """
        ```
        key=value
        timeout=30
        ```
        """
        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(
            blocks[0],
            .code(CodeBlock(language: nil, code: "key=value\ntimeout=30", isComplete: true))
        )
    }

    // 4. Two blocks in one message
    func testTwoBlocksInOneMessage() {
        let markdown = """
        First example:
        ```swift
        let count = 42
        ```
        Second example without language:
        ```
        echo "Done"
        ```
        All done!
        """
        let blocks = MarkdownBlockParser.parse(markdown)

        XCTAssertEqual(blocks.count, 5)

        XCTAssertEqual(blocks[0], .text("First example:"))
        XCTAssertEqual(blocks[1], .code(CodeBlock(language: "swift", code: "let count = 42", isComplete: true)))
        XCTAssertEqual(blocks[2], .text("Second example without language:"))
        XCTAssertEqual(blocks[3], .code(CodeBlock(language: nil, code: "echo \"Done\"", isComplete: true)))
        XCTAssertEqual(blocks[4], .text("All done!"))
    }

    // 5. An unclosed block while streaming
    func testUnclosedBlockWhileStreaming() {
        let streamingMarkdown = """
        Here is the code as it streams:
        ```swift
        func processItem() {
            let item = "active"
        """
        let blocks = MarkdownBlockParser.parse(streamingMarkdown)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0], .text("Here is the code as it streams:"))

        let expectedPartialCode = "func processItem() {\n    let item = \"active\""
        XCTAssertEqual(
            blocks[1],
            .code(CodeBlock(language: "swift", code: expectedPartialCode, isComplete: false))
        )

        // Also test immediate opening fence with no code lines yet
        let justOpened = "Intro\n```swift"
        let openedBlocks = MarkdownBlockParser.parse(justOpened)
        XCTAssertEqual(openedBlocks.count, 2)
        XCTAssertEqual(openedBlocks[0], .text("Intro"))
        XCTAssertEqual(openedBlocks[1], .code(CodeBlock(language: "swift", code: "", isComplete: false)))
    }

    // 6. An empty block
    func testEmptyBlock() {
        // Empty block with language
        let emptyWithLang = """
        ```swift
        ```
        """
        let blocksWithLang = MarkdownBlockParser.parse(emptyWithLang)
        XCTAssertEqual(blocksWithLang.count, 1)
        XCTAssertEqual(blocksWithLang[0], .code(CodeBlock(language: "swift", code: "", isComplete: true)))

        // Empty block without language
        let emptyWithoutLang = """
        ```
        ```
        """
        let blocksWithoutLang = MarkdownBlockParser.parse(emptyWithoutLang)
        XCTAssertEqual(blocksWithoutLang.count, 1)
        XCTAssertEqual(blocksWithoutLang[0], .code(CodeBlock(language: nil, code: "", isComplete: true)))

        // Single-line closed empty block
        let singleLineEmpty = "```swift```"
        let singleLineBlocks = MarkdownBlockParser.parse(singleLineEmpty)
        XCTAssertEqual(singleLineBlocks.count, 1)
        XCTAssertEqual(singleLineBlocks[0], .code(CodeBlock(language: "swift", code: "", isComplete: true)))
    }

    // Preservation of exact line breaks and indentation
    func testPreservesIndentationAndLineBreaks() {
        let codeWithIndentation = """
        ```python
        def outer():
            def inner():
                # 8 spaces of indentation
                return 1

            return inner()
        ```
        """
        let blocks = MarkdownBlockParser.parse(codeWithIndentation)
        XCTAssertEqual(blocks.count, 1)

        guard case .code(let block) = blocks[0] else {
            XCTFail("Expected .code block")
            return
        }

        XCTAssertEqual(block.language, "python")
        let lines = block.code.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 6)
        XCTAssertEqual(lines[0], "def outer():")
        XCTAssertEqual(lines[1], "    def inner():")
        XCTAssertEqual(lines[2], "        # 8 spaces of indentation")
        XCTAssertEqual(lines[3], "        return 1")
        XCTAssertEqual(lines[4], "")
        XCTAssertEqual(lines[5], "    return inner()")
    }

    func testMockCannedResponseParsing() {
        let blocks = MarkdownBlockParser.parse(MockAIService.defaultCannedResponse)
        XCTAssertEqual(blocks.count, 5)

        // Block 3 is the unlabeled configuration code block
        guard case .code(let unlabeledBlock) = blocks[3] else {
            XCTFail("Expected unlabeled code block at index 3")
            return
        }

        XCTAssertNil(unlabeledBlock.language)
        let expectedCode = """
        server.port = 8080
        server.host = "127.0.0.1"
        environment = "development"
        debug = true
        """
        XCTAssertEqual(unlabeledBlock.code, expectedCode)
        XCTAssertFalse(unlabeledBlock.code.contains("…"), "Code should not contain ellipsis character")
    }

    func testEmptyInput() {
        XCTAssertEqual(MarkdownBlockParser.parse(""), [])
    }
}
