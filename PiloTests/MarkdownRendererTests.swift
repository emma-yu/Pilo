import XCTest
@testable import Pilo

/// Markdown 预览：line-based parser 的覆盖测试。
/// 验证：heading / paragraph / list / code block / quote / hr / 太长拒绝。
final class MarkdownRendererTests: XCTestCase {

    private func parse(_ src: String) -> [MarkdownDocument.Block] {
        MarkdownRenderer.parse(src).blocks
    }

    // MARK: - Heading

    func testH1() {
        let blocks = parse("# Hello")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(let lvl, _, _) = blocks[0] {
            XCTAssertEqual(lvl, 1)
        } else {
            XCTFail("expected heading")
        }
    }

    func testH2H3() {
        let blocks = parse("## Two\n\n### Three")
        let levels = blocks.compactMap { b -> Int? in
            if case .heading(let l, _, _) = b { return l }
            return nil
        }
        XCTAssertEqual(levels, [2, 3])
    }

    func testHashWithoutSpaceIsNotHeading() {
        let blocks = parse("#NotAHeading")
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph = blocks[0] {} else {
            XCTFail("# with no space should be paragraph")
        }
    }

    // MARK: - Paragraph

    func testParagraph() {
        let blocks = parse("Hello world.")
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph = blocks[0] {} else { XCTFail("expected paragraph") }
    }

    func testMultilineParagraphFolded() {
        // 连续两行不空 → 同一 paragraph
        let blocks = parse("Line one\nLine two")
        let paragraphs = blocks.filter { if case .paragraph = $0 { return true }; return false }
        XCTAssertEqual(paragraphs.count, 1, "连续两行应合并成一个段落")
    }

    func testEmptyLineBreaksParagraph() {
        let blocks = parse("First.\n\nSecond.")
        let paragraphs = blocks.filter { if case .paragraph = $0 { return true }; return false }
        XCTAssertEqual(paragraphs.count, 2)
    }

    // MARK: - Code block

    func testFencedCodeBlock() {
        let src = """
        ```
        let x = 1
        let y = 2
        ```
        """
        let blocks = parse(src)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(_, let code) = blocks[0] {
            XCTAssertEqual(code, "let x = 1\nlet y = 2")
        } else {
            XCTFail("expected code block")
        }
    }

    func testCodeBlockWithLanguage() {
        let src = """
        ```swift
        let x = 1
        ```
        """
        let blocks = parse(src)
        if case .codeBlock(let lang, _) = blocks[0] {
            XCTAssertEqual(lang, "swift")
        } else { XCTFail("expected code block") }
    }

    func testCodeBlockPreservesMarkdownInside() {
        // code block 内不被进一步解析
        let src = """
        ```
        # not a heading
        - not a bullet
        ```
        """
        let blocks = parse(src)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(_, let code) = blocks[0] {
            XCTAssertTrue(code.contains("# not a heading"))
            XCTAssertTrue(code.contains("- not a bullet"))
        } else { XCTFail("expected code block") }
    }

    // MARK: - List

    func testBulletList() {
        let blocks = parse("- one\n- two\n- three")
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items) = blocks[0] {
            XCTAssertEqual(items.count, 3)
        } else { XCTFail("expected bullet list") }
    }

    func testStarBulletList() {
        let blocks = parse("* one\n* two")
        if case .bulletList(let items) = blocks[0] {
            XCTAssertEqual(items.count, 2)
        } else { XCTFail("expected bullet list") }
    }

    func testOrderedList() {
        let blocks = parse("1. first\n2. second\n10. tenth")
        XCTAssertEqual(blocks.count, 1)
        if case .orderedList(let items) = blocks[0] {
            XCTAssertEqual(items.count, 3)
        } else { XCTFail("expected ordered list") }
    }

    func testListBreaksOnEmptyLine() {
        let blocks = parse("- a\n- b\n\n- c")
        let lists = blocks.filter { if case .bulletList = $0 { return true }; return false }
        XCTAssertEqual(lists.count, 2, "空行应该把列表切两段")
    }

    // MARK: - Quote

    func testQuote() {
        let blocks = parse("> a wise saying")
        if case .quote = blocks[0] {} else { XCTFail("expected quote") }
    }

    func testMultilineQuoteFolded() {
        let blocks = parse("> first line\n> second line")
        let quotes = blocks.filter { if case .quote = $0 { return true }; return false }
        XCTAssertEqual(quotes.count, 1)
    }

    // MARK: - Horizontal rule

    func testHorizontalRuleDashes() {
        let blocks = parse("a\n\n---\n\nb")
        let hrs = blocks.filter { if case .horizontalRule = $0 { return true }; return false }
        XCTAssertEqual(hrs.count, 1)
    }

    func testHorizontalRuleAsterisks() {
        let blocks = parse("a\n\n***\n\nb")
        let hrs = blocks.filter { if case .horizontalRule = $0 { return true }; return false }
        XCTAssertEqual(hrs.count, 1)
    }

    // MARK: - 文件大小限制

    func testTooLargeIsTruncated() {
        // 构造 > 500KB 的文档
        let huge = String(repeating: "x ", count: 300_000)
        let doc = MarkdownRenderer.parse(huge)
        XCTAssertTrue(doc.truncated)
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testTooManyLinesIsTruncated() {
        let lines = Array(repeating: "x", count: 6000).joined(separator: "\n")
        let doc = MarkdownRenderer.parse(lines)
        XCTAssertTrue(doc.truncated)
    }

    // MARK: - 组合

    func testRealisticDocument() {
        let src = """
        # Title

        Intro paragraph.

        ## Section

        - item 1
        - item 2

        ```swift
        let x = 1
        ```

        > A quote.

        ---

        End.
        """
        let blocks = MarkdownRenderer.parse(src).blocks
        // 至少应该有：h1, paragraph, h2, list, code, quote, hr, paragraph
        let kinds = blocks.compactMap { b -> String? in
            switch b {
            case .heading: return "h"
            case .paragraph: return "p"
            case .bulletList: return "ul"
            case .codeBlock: return "code"
            case .quote: return "q"
            case .horizontalRule: return "hr"
            default: return nil
            }
        }
        XCTAssertTrue(kinds.contains("h"))
        XCTAssertTrue(kinds.contains("p"))
        XCTAssertTrue(kinds.contains("ul"))
        XCTAssertTrue(kinds.contains("code"))
        XCTAssertTrue(kinds.contains("q"))
        XCTAssertTrue(kinds.contains("hr"))
    }

    func testEmptyDocument() {
        XCTAssertEqual(parse("").count, 0)
    }
}
