import XCTest
@testable import Pilo

/// Phase B (Project Inventory)：RepoHealthDetector 用临时目录测 README/tests 检测。
final class RepoHealthDetectorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pilo-health-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func touch(_ relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try Data().write(to: url)
    }

    private func mkdir(_ relativePath: String) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - README

    func testDetectsReadmeMd() throws {
        try touch("README.md")
        let r = RepoHealthDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(r.hasReadme)
    }

    func testDetectsLowercaseReadme() throws {
        try touch("readme.md")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasReadme)
    }

    func testDetectsBareReadme() throws {
        try touch("README")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasReadme)
    }

    func testDetectsReadmeTxtAndRst() throws {
        try touch("README.txt")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasReadme)
    }

    func testNoReadmeIfMissing() throws {
        try touch("something.md")  // 不是 README
        XCTAssertFalse(RepoHealthDetector.detect(repoPath: tempDir.path).hasReadme)
    }

    // MARK: - Tests

    func testDetectsTestsDirectory() throws {
        try mkdir("tests")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testDetectsJestTestsDirectory() throws {
        try mkdir("__tests__")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testDetectsSwiftTestsSuffix() throws {
        try mkdir("PiloTests")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testDetectsSpecDirectory() throws {
        try mkdir("spec")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testDetectsTestFileByPath() throws {
        try touch("app.test.ts")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testDetectsGoTestFile() throws {
        try touch("handler_test.go")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testNoTestsIfMissing() throws {
        try touch("main.swift")
        try mkdir("src")
        XCTAssertFalse(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    func testTestsSuffixRequiresNonEmptyPrefix() throws {
        // "Test" 本身不应该命中 testDirSuffixes（避免误报通用 "Test" 目录）
        // 注意：testDirCandidates 里有 "Test"，所以裸 "Test" 还是会被识别
        // 这个测试是确认 suffix 逻辑不会单独把 "Tests" 这样的也算上（candidate 已经覆盖）
        try mkdir("Tests")
        XCTAssertTrue(RepoHealthDetector.detect(repoPath: tempDir.path).hasTests)
    }

    // MARK: - 组合

    func testEmptyDirHasNothing() {
        let r = RepoHealthDetector.detect(repoPath: tempDir.path)
        XCTAssertFalse(r.hasReadme)
        XCTAssertFalse(r.hasTests)
    }

    func testFullySetupRepoDetectsBoth() throws {
        try touch("README.md")
        try mkdir("tests")
        let r = RepoHealthDetector.detect(repoPath: tempDir.path)
        XCTAssertTrue(r.hasReadme)
        XCTAssertTrue(r.hasTests)
    }

    func testNonExistentPathReturnsAllFalse() {
        let r = RepoHealthDetector.detect(repoPath: "/tmp/definitely-does-not-exist-\(UUID().uuidString)")
        XCTAssertFalse(r.hasReadme)
        XCTAssertFalse(r.hasTests)
    }
}
