import XCTest
@testable import Pilo

final class CommitGuardScannerTests: XCTestCase {

    var scanner: CommitGuardScanner!
    let repoId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        scanner = CommitGuardScanner()
    }

    // MARK: - 测试用 size provider

    private func makeSizeProvider(_ sizes: [String: Int64] = [:]) -> @Sendable (String) async -> Int64? {
        return { path in sizes[path] }
    }

    // MARK: - .env

    func testEnvBlocked() async {
        let findings = await scanner.scan(
            changedFiles: [(".env", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.kind, .envFile)
        XCTAssertEqual(findings.first?.severity, .critical)
    }

    func testEnvLocalBlocked() async {
        let findings = await scanner.scan(
            changedFiles: [(".env.local", "A"), (".env.production", "M")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.filter { $0.kind == .envFile }.count, 2)
    }

    func testEnvExampleAllowed() async {
        let findings = await scanner.scan(
            changedFiles: [(".env.example", "A"), (".env.sample", "A"), (".env.template", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertTrue(findings.filter { $0.kind == .envFile }.isEmpty,
                      ".env.example/.env.sample/.env.template 永远不报")
    }

    func testEnvDeletedSkipped() async {
        let findings = await scanner.scan(
            changedFiles: [(".env", "D")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertTrue(findings.isEmpty, "删除 .env 是修复，不应报")
    }

    // MARK: - 私钥

    func testPemBlocked() async {
        let findings = await scanner.scan(
            changedFiles: [("certs/server.pem", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .privateKey)
        XCTAssertEqual(findings.first?.severity, .critical)
    }

    func testIdRsaBlocked() async {
        let findings = await scanner.scan(
            changedFiles: [("id_rsa", "A"), ("id_ed25519", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.filter { $0.kind == .privateKey }.count, 2)
    }

    func testPubKeyIsWarning() async {
        let findings = await scanner.scan(
            changedFiles: [("id_rsa.pub", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .publicKey)
        XCTAssertEqual(findings.first?.severity, .warning)
    }

    // MARK: - 大小

    func testLargeFileWarning() async {
        let size: Int64 = 60 * 1024 * 1024   // 60 MB
        let findings = await scanner.scan(
            changedFiles: [("assets/video.mp4", "A")],
            sizeFor: makeSizeProvider(["assets/video.mp4": size]),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .largeFile)
        XCTAssertEqual(findings.first?.severity, .warning)
    }

    func testOversizeBlocked() async {
        let size: Int64 = 120 * 1024 * 1024  // 120 MB
        let findings = await scanner.scan(
            changedFiles: [("assets/big.bin", "A")],
            sizeFor: makeSizeProvider(["assets/big.bin": size]),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .oversizeBlocked)
        XCTAssertEqual(findings.first?.severity, .critical)
    }

    func testSmallFileNotReported() async {
        let findings = await scanner.scan(
            changedFiles: [("src/main.swift", "A")],
            sizeFor: makeSizeProvider(["src/main.swift": 5000]),
            repoId: repoId
        )
        XCTAssertTrue(findings.isEmpty)
    }

    // MARK: - 构建产物 + DS_Store

    func testNodeModulesWarning() async {
        let findings = await scanner.scan(
            changedFiles: [("node_modules/react/index.js", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .buildArtifact)
        XCTAssertEqual(findings.first?.severity, .warning)
    }

    func testDistDirWarning() async {
        let findings = await scanner.scan(
            changedFiles: [("dist/bundle.js", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .buildArtifact)
    }

    func testDSStoreWarning() async {
        let findings = await scanner.scan(
            changedFiles: [("src/.DS_Store", "A")],
            sizeFor: makeSizeProvider(),
            repoId: repoId
        )
        XCTAssertEqual(findings.first?.kind, .dsStore)
        XCTAssertEqual(findings.first?.severity, .warning)
    }

    // MARK: - 建议

    func testEnvSuggestsGitignorePattern() {
        let f = CommitGuardFinding(repoId: repoId, filePath: ".env", fileSize: nil, kind: .envFile)
        if case .addToGitignore(let pattern) = f.suggestion {
            XCTAssertTrue(pattern.contains(".env"))
            XCTAssertTrue(pattern.contains("!.env.example"))
        } else {
            XCTFail("envFile 应该建议加入 .gitignore")
        }
    }

    func testLargeFileSuggestsLFS() {
        let f = CommitGuardFinding(
            repoId: repoId, filePath: "video.mp4",
            fileSize: 60 * 1024 * 1024, kind: .largeFile
        )
        guard case .useLFS = f.suggestion else {
            XCTFail("largeFile 应该建议 LFS")
            return
        }
    }
}
