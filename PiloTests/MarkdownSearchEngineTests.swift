import XCTest
@testable import Pilo

/// MarkdownSearchEngine: in-doc 全文搜索逻辑测试
final class MarkdownSearchEngineTests: XCTestCase {

    private func makeDoc(_ blocks: [MarkdownDocument.Block]) -> MarkdownDocument {
        MarkdownDocument(blocks: blocks, truncated: false, totalLines: 0)
    }

    private func paragraph(_ text: String) -> MarkdownDocument.Block {
        .paragraph(content: AttributedString(text))
    }

    private func heading(_ text: String) -> MarkdownDocument.Block {
        .heading(level: 1, content: AttributedString(text), anchor: "h0")
    }

    private func code(_ text: String) -> MarkdownDocument.Block {
        .codeBlock(language: nil, code: text)
    }

    private func bulletList(_ items: [String]) -> MarkdownDocument.Block {
        .bulletList(items: items.map { AttributedString($0) })
    }

    // MARK: - 基础

    func testFindSingleMatch() {
        let doc = makeDoc([paragraph("hello world")])
        let hits = MarkdownSearchEngine.find(in: doc, query: "world")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].blockIndex, 0)
        XCTAssertEqual(hits[0].occurrenceInBlock, 0)
    }

    func testFindMultipleMatchesInOneParagraph() {
        let doc = makeDoc([paragraph("foo foo foo")])
        let hits = MarkdownSearchEngine.find(in: doc, query: "foo")
        XCTAssertEqual(hits.count, 3)
        XCTAssertEqual(hits.map(\.occurrenceInBlock), [0, 1, 2])
    }

    func testFindAcrossBlocks() {
        let doc = makeDoc([
            paragraph("Apple"),
            paragraph("Banana"),
            paragraph("Apple pie"),
        ])
        let hits = MarkdownSearchEngine.find(in: doc, query: "apple")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].blockIndex, 0)
        XCTAssertEqual(hits[1].blockIndex, 2)
    }

    // MARK: - Case insensitive

    func testCaseInsensitive() {
        let doc = makeDoc([paragraph("Hello WORLD")])
        XCTAssertEqual(MarkdownSearchEngine.find(in: doc, query: "world").count, 1)
        XCTAssertEqual(MarkdownSearchEngine.find(in: doc, query: "WORLD").count, 1)
        XCTAssertEqual(MarkdownSearchEngine.find(in: doc, query: "wOrLd").count, 1)
    }

    // MARK: - 空 / 边界

    func testEmptyQueryReturnsNoHits() {
        let doc = makeDoc([paragraph("hello")])
        XCTAssertTrue(MarkdownSearchEngine.find(in: doc, query: "").isEmpty)
    }

    func testWhitespaceOnlyQueryReturnsNoHits() {
        let doc = makeDoc([paragraph("hello")])
        XCTAssertTrue(MarkdownSearchEngine.find(in: doc, query: "   ").isEmpty)
    }

    func testNoMatchesReturnsEmpty() {
        let doc = makeDoc([paragraph("hello")])
        XCTAssertTrue(MarkdownSearchEngine.find(in: doc, query: "xyz").isEmpty)
    }

    func testEmptyDocumentReturnsEmpty() {
        let doc = makeDoc([])
        XCTAssertTrue(MarkdownSearchEngine.find(in: doc, query: "anything").isEmpty)
    }

    // MARK: - 跨 block 类型

    func testHeadingsAlsoSearched() {
        let doc = makeDoc([heading("Important"), paragraph("body")])
        let hits = MarkdownSearchEngine.find(in: doc, query: "important")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].blockIndex, 0)
    }

    func testListItemsAlsoSearched() {
        let doc = makeDoc([bulletList(["red apple", "green apple", "yellow banana"])])
        let hits = MarkdownSearchEngine.find(in: doc, query: "apple")
        XCTAssertEqual(hits.count, 2)
        // 同 block 内多个 item 的 occurrenceInBlock 跨 item 累加
        XCTAssertEqual(hits[0].occurrenceInBlock, 0)
        XCTAssertEqual(hits[1].occurrenceInBlock, 1)
    }

    func testCodeBlocksNotSearched() {
        // 故意跳过 code block —— 否则用户搜 "text" 会大量误命中代码 / variable
        let doc = makeDoc([
            paragraph("hello text"),
            code("let text = \"text in code\""),
            paragraph("more text"),
        ])
        let hits = MarkdownSearchEngine.find(in: doc, query: "text")
        XCTAssertEqual(hits.count, 2, "代码块内的命中应被跳过")
        XCTAssertEqual(hits[0].blockIndex, 0)
        XCTAssertEqual(hits[1].blockIndex, 2)
    }

    // MARK: - 中文

    func testChineseSearch() {
        // 邮 出现 3 次：邮局 / 邮票 / 邮筒
        let doc = makeDoc([paragraph("邮局风格 Pilo 邮票 邮筒")])
        let hits = MarkdownSearchEngine.find(in: doc, query: "邮")
        XCTAssertEqual(hits.count, 3)
    }

    // MARK: - Overlap

    func testNonOverlappingMatches() {
        // "aaa" 在 "aaaa" 里只匹配一次（advance to upperBound 不重叠），
        // 不是 "abc" pattern 的 2 次。简化逻辑。
        let doc = makeDoc([paragraph("aaaa")])
        let hits = MarkdownSearchEngine.find(in: doc, query: "aa")
        XCTAssertEqual(hits.count, 2, "'aaaa' 含 'aa' 两次（不重叠）")
    }
}
