import XCTest
@testable import Pilo

final class GitignoreEditorTests: XCTestCase {

    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pilo-gitignore-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func readGitignore() throws -> String {
        try String(contentsOf: tempDir.appendingPathComponent(".gitignore"), encoding: .utf8)
    }

    func testAppendsToFreshRepo() throws {
        let result = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        XCTAssertEqual(result.addedLines, [".env"])
        XCTAssertTrue(result.alreadyPresent.isEmpty)
        XCTAssertTrue(try readGitignore().contains(".env"))
    }

    func testIdempotentForSameLine() throws {
        _ = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        let result = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        XCTAssertTrue(result.addedLines.isEmpty, "重复追加同一行不应再写入")
        XCTAssertEqual(result.alreadyPresent, [".env"])
    }

    func testMultilinePatternHandled() throws {
        let pattern = ".env\n.env.*\n!.env.example"
        let result = try GitignoreEditor.append(pattern: pattern, toRepoAt: tempDir.path)
        XCTAssertEqual(result.addedLines.count, 3)
        let content = try readGitignore()
        XCTAssertTrue(content.contains(".env\n"))
        XCTAssertTrue(content.contains(".env.*\n"))
        XCTAssertTrue(content.contains("!.env.example"))
    }

    func testPreservesExistingContent() throws {
        // 预先放点用户已有内容
        let existing = "# user's rules\n*.tmp\nbuild/\n"
        try existing.write(
            to: tempDir.appendingPathComponent(".gitignore"),
            atomically: true, encoding: .utf8
        )
        _ = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        let content = try readGitignore()
        XCTAssertTrue(content.contains("# user's rules"))
        XCTAssertTrue(content.contains("*.tmp"))
        XCTAssertTrue(content.contains("build/"))
        XCTAssertTrue(content.contains(".env"))
    }

    func testAddsTimestampHeader() throws {
        _ = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        let content = try readGitignore()
        XCTAssertTrue(content.contains("# Added by Pilo"))
    }

    func testEmptyLinesIgnored() throws {
        let result = try GitignoreEditor.append(pattern: "\n\n.env\n\n", toRepoAt: tempDir.path)
        XCTAssertEqual(result.addedLines, [".env"])
    }

    func testPartialOverlap() throws {
        // 先有 .env
        _ = try GitignoreEditor.append(pattern: ".env", toRepoAt: tempDir.path)
        // 再追加多行，包含 .env 和新行
        let result = try GitignoreEditor.append(
            pattern: ".env\n.env.local\n!.env.example",
            toRepoAt: tempDir.path
        )
        XCTAssertEqual(result.addedLines, [".env.local", "!.env.example"])
        XCTAssertEqual(result.alreadyPresent, [".env"])
    }
}
