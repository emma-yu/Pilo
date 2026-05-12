import XCTest
@testable import Pilo

/// MarkdownTOC.extract: 从 blocks 提 heading TOC items 的逻辑测试
final class MarkdownTOCTests: XCTestCase {

    private func heading(_ level: Int, _ text: String, anchor: String = "h0") -> MarkdownDocument.Block {
        .heading(level: level, content: AttributedString(text), anchor: anchor)
    }

    private func paragraph(_ text: String) -> MarkdownDocument.Block {
        .paragraph(content: AttributedString(text))
    }

    // MARK: - 基础

    func testHeadingsExtractedInOrder() {
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "Top"),
            paragraph("intro"),
            heading(2, "Section A"),
            paragraph("body"),
            heading(2, "Section B"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertEqual(items.map(\.text), ["Top", "Section A", "Section B"])
        XCTAssertEqual(items.map(\.level), [1, 2, 2])
    }

    func testBlockIndicesPreserved() {
        // blockIndex 必须匹配 blocks 数组下标 —— 用于 scrollTo
        let blocks: [MarkdownDocument.Block] = [
            paragraph("p1"),    // 0
            heading(1, "T"),    // 1
            paragraph("p2"),    // 2
            heading(2, "S"),    // 3
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertEqual(items.map(\.blockIndex), [1, 3])
    }

    func testEmptyBlocksGivesEmptyTOC() {
        let items = MarkdownTOC.extract(from: [])
        XCTAssertTrue(items.isEmpty)
    }

    func testNoHeadingsGivesEmptyTOC() {
        let blocks: [MarkdownDocument.Block] = [
            paragraph("just"),
            paragraph("text"),
            .horizontalRule,
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - 边界

    func testH4PlusIncluded() {
        // 深层 heading 也要进 TOC（缩进会处理视觉层级）
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "T"),
            heading(4, "Deep"),
            heading(6, "Very Deep"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.last?.level, 6)
    }

    func testWhitespaceTrimmed() {
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "  Spacy Title  \n"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertEqual(items.first?.text, "Spacy Title")
    }

    func testEmptyHeadingSkipped() {
        // "#" 但后面没文字的 heading（解析结果）—— 不该进 TOC（空 row 难看）
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "   "),
            heading(2, "Real"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.text, "Real")
    }

    // MARK: - 显示阈值

    func testMinHeadingsToShowIsFour() {
        // 阈值变了视觉会显著不同；测试守门
        XCTAssertEqual(MarkdownTOC.minHeadingsToShow, 4)
    }

    func testThreeHeadingsBelowThreshold() {
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "A"),
            heading(2, "B"),
            heading(2, "C"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertLessThan(items.count, MarkdownTOC.minHeadingsToShow,
                          "3 个 heading 应低于显示阈值（4）")
    }

    func testFourHeadingsAtThreshold() {
        let blocks: [MarkdownDocument.Block] = [
            heading(1, "A"),
            heading(2, "B"),
            heading(2, "C"),
            heading(3, "D"),
        ]
        let items = MarkdownTOC.extract(from: blocks)
        XCTAssertGreaterThanOrEqual(items.count, MarkdownTOC.minHeadingsToShow)
    }
}
