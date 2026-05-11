import XCTest
@testable import Pilo

/// Resume Work：`git status --porcelain` 解析正确性。
final class UncommittedFileParsingTests: XCTestCase {

    private func parse(_ porcelain: String, limit: Int = 20) -> [UncommittedFile] {
        GitClient.parseUncommittedFiles(porcelain: porcelain, limit: limit)
    }

    func testEmpty() {
        XCTAssertEqual(parse("").count, 0)
    }

    func testSingleModified() {
        let out = parse(" M Pilo/Models/AppState.swift")
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].status, .modified)
        XCTAssertEqual(out[0].path, "Pilo/Models/AppState.swift")
    }

    func testStagedModified() {
        let out = parse("M  README.md")
        XCTAssertEqual(out.first?.status, .modified)
        XCTAssertEqual(out.first?.path, "README.md")
    }

    func testStagedAndUnstagedModified() {
        let out = parse("MM file.swift")
        XCTAssertEqual(out.first?.status, .modified)
    }

    func testUntracked() {
        let out = parse("?? new-file.swift")
        XCTAssertEqual(out.first?.status, .untracked)
        XCTAssertEqual(out.first?.path, "new-file.swift")
    }

    func testDeleted() {
        let out = parse(" D removed.swift")
        XCTAssertEqual(out.first?.status, .deleted)
    }

    func testStagedDeleted() {
        let out = parse("D  removed.swift")
        XCTAssertEqual(out.first?.status, .deleted)
    }

    func testAdded() {
        let out = parse("A  brand-new.swift")
        XCTAssertEqual(out.first?.status, .added)
    }

    func testRenamed() {
        let out = parse("R  old.swift -> new.swift")
        XCTAssertEqual(out.first?.status, .renamed)
        XCTAssertEqual(out.first?.path, "new.swift", "rename 应取新路径")
    }

    func testConflicted() {
        let out = parse("UU conflicted.swift")
        XCTAssertEqual(out.first?.status, .conflicted)
    }

    func testMixed() {
        let input = """
        ?? new.swift
        M  modified.swift
         D deleted.swift
        R  old.swift -> new-name.swift
        """
        let out = parse(input)
        XCTAssertEqual(out.count, 4)
        XCTAssertEqual(out[0].status, .untracked)
        XCTAssertEqual(out[1].status, .modified)
        XCTAssertEqual(out[2].status, .deleted)
        XCTAssertEqual(out[3].status, .renamed)
        XCTAssertEqual(out[3].path, "new-name.swift")
    }

    func testLimit() {
        let lines = (0..<10).map { "?? file\($0).swift" }.joined(separator: "\n")
        let out = parse(lines, limit: 3)
        XCTAssertEqual(out.count, 3)
    }

    func testPathWithSpaces() {
        let out = parse(" M path with spaces.swift")
        XCTAssertEqual(out.first?.path, "path with spaces.swift")
    }

    func testShortLineIgnored() {
        // 不满 4 字符的行跳过（无效 porcelain）
        let out = parse("M")
        XCTAssertEqual(out.count, 0)
    }
}
