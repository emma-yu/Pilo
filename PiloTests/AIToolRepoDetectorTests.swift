import XCTest
@testable import Pilo

/// AIToolRepoDetector：per-repo "Configured for" 检测。
/// 每个测试用一个临时目录，写若干 fake config 文件 / 目录，
/// 验证检测结果。
final class AIToolRepoDetectorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pilo-ai-detect-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeFile(_ name: String, content: String = "x") throws {
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeDir(_ name: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Claude Code

    func testClaudeFromCLAUDEMd() throws {
        try writeFile("CLAUDE.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.claudeCode))
    }

    func testClaudeFromLowercaseClaudeMd() throws {
        try writeFile("claude.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.claudeCode), "大小写不敏感")
    }

    func testClaudeFromDotClaudeDir() throws {
        try writeDir(".claude")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.claudeCode))
    }

    // MARK: - Cursor

    func testCursorFromCursorrules() throws {
        try writeFile(".cursorrules")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.cursor))
    }

    func testCursorFromMDC() throws {
        // 根目录任一 .mdc 文件（Cursor 0.42+ rules 格式）
        try writeFile("project.mdc")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.cursor))
    }

    func testCursorFromDotCursorDir() throws {
        try writeDir(".cursor")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.cursor))
    }

    // MARK: - Codex

    func testCodexFromAGENTSMd() throws {
        try writeFile("AGENTS.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.codex))
    }

    func testCodexFromCodexMd() throws {
        try writeFile("codex.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.codex))
    }

    // MARK: - Windsurf

    func testWindsurfFromWindsurfrules() throws {
        try writeFile(".windsurfrules")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.windsurf))
    }

    func testWindsurfFromDotWindsurfDir() throws {
        try writeDir(".windsurf")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.windsurf))
    }

    // MARK: - Aider

    func testAiderFromConventionsMd() throws {
        try writeFile("CONVENTIONS.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.aider))
    }

    func testAiderFromDotAiderFiles() throws {
        // Aider 会留 .aider.chat.history.md / .aider.input.history 等
        try writeFile(".aider.chat.history.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.aider))
    }

    // MARK: - Gemini

    func testGeminiFromGeminiMd() throws {
        try writeFile("GEMINI.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.gemini))
    }

    func testGeminiFromDotGeminiDir() throws {
        try writeDir(".gemini")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.gemini))
    }

    // MARK: - Coexistence

    func testMultipleToolsCoexist() throws {
        // 真实场景：一个仓库同时配置 Claude Code + Cursor + Codex
        try writeFile("CLAUDE.md")
        try writeFile(".cursorrules")
        try writeFile("AGENTS.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertEqual(result, Set<AITool>([.claudeCode, .cursor, .codex]))
    }

    // MARK: - Empty / 异常

    func testEmptyRepoDetectsNone() throws {
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.isEmpty)
    }

    func testNonExistentRepoDetectsNone() {
        let result = AIToolRepoDetector.detect(repoPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 非配置文件应不误判

    func testRandomMdFileDoesNotTriggerAnyTool() throws {
        // 一般的 README / NOTES 不该触发任何 AI 工具检测
        try writeFile("README.md")
        try writeFile("NOTES.md")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.isEmpty, "通用 .md 文件不该被误判为 AI 工具配置")
    }

    func testRegularMdcSuffixDoesTriggerCursor() throws {
        // .mdc 是 Cursor 专属 —— 即便文件名跟 cursor 无关也应该识别
        try writeFile("some-rules.mdc")
        let result = AIToolRepoDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(result.contains(.cursor))
    }

    // MARK: - sortedForDisplay 显示顺序

    func testSortedForDisplayPutsClaudeCodeFirst() {
        let tools: Set<AITool> = [.aider, .gemini, .claudeCode, .cursor]
        let sorted = AIToolStamp.sortedForDisplay(tools)
        XCTAssertEqual(sorted, [.claudeCode, .cursor, .gemini, .aider])
    }
}
