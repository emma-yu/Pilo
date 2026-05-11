import XCTest
@testable import Pilo

/// 项目文档面板：RepoDocsIndexer 用 temp dir 测各种文档名 + docs/ 子目录 + mtime 排序。
final class RepoDocsIndexerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pilo-docs-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ relativePath: String, content: String = "x", modifiedDaysAgo: Double? = nil) throws {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
        if let days = modifiedDaysAgo {
            let date = Date().addingTimeInterval(-days * 86400)
            try FileManager.default.setAttributes(
                [.modificationDate: date],
                ofItemAtPath: url.path
            )
        }
    }

    // MARK: - Root level

    func testFindsReadmeMd() throws {
        try write("README.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].kind, .readme)
        XCTAssertEqual(docs[0].name, "README.md")
    }

    func testFindsLowercaseReadme() throws {
        try write("readme.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .readme)
    }

    func testFindsChangelog() throws {
        try write("CHANGELOG.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .changelog)
    }

    func testFindsTodo() throws {
        try write("TODO.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .todo)
    }

    func testFindsPrd() throws {
        try write("PRD.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .prd)
    }

    func testFindsArchitecture() throws {
        try write("ARCHITECTURE.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .architecture)
    }

    func testFindsImplementation() throws {
        try write("IMPLEMENTATION.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .architecture)
    }

    func testRootLevelRandomMdNowIncludedAsGeneric() throws {
        // 新行为：根级 .md 全部纳入；不命中 prefix 表的 kind = .generic
        // （之前的限制太严，用户的 DESIGN_NOTES.md / SCRATCH.md 都会漏）
        try write("scratch.md")
        try write("ideas-list.md")  // ideas 在 prefixes 里 → notes
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 2)
        XCTAssertEqual(docs.first(where: { $0.name == "scratch.md" })?.kind, .generic)
        XCTAssertEqual(docs.first(where: { $0.name == "ideas-list.md" })?.kind, .notes)
    }

    // MARK: - LICENSE 系列（含无扩展）

    func testFindsBareLicense() throws {
        try write("LICENSE")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].kind, .license)
        XCTAssertEqual(docs[0].name, "LICENSE")
    }

    func testFindsLicenseMd() throws {
        try write("LICENSE.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .license)
    }

    func testFindsCopying() throws {
        try write("COPYING")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .license)
    }

    func testFindsAuthorsAndNotice() throws {
        try write("AUTHORS")
        try write("NOTICE")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 2)
        XCTAssertTrue(docs.allSatisfy { $0.kind == .license })
    }

    func testFindsSecurity() throws {
        try write("SECURITY.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .contributing)
    }

    func testFindsCodeOfConduct() throws {
        try write("CODE_OF_CONDUCT.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .contributing)
    }

    // MARK: - AI coding 时代专属

    func testFindsClaudeMd() throws {
        try write("CLAUDE.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].kind, .aiInstructions)
    }

    func testFindsAgentsMd() throws {
        try write("AGENTS.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .aiInstructions)
    }

    func testFindsCursorRules() throws {
        try write(".cursorrules")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].kind, .aiInstructions)
    }

    func testIgnoresOtherDotfiles() throws {
        // .DS_Store 等不是 .cursorrules 的隐藏文件应该跳过
        try write(".env")
        try write(".gitignore")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 0)
    }

    // MARK: - docs/ 二级递归

    func testRecursesDocsSubdirectoryTwoLevelsDeep() throws {
        try write("docs/api/v1/spec.md")  // 第 2 级 docs → 应找到
        try write("docs/top-level.md")     // 第 1 级
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 2)
        XCTAssertNotNil(docs.first(where: { $0.relativePath == "docs/api/v1/spec.md" }))
    }

    func testScansNotesAndDesignDirs() throws {
        try write("notes/meeting-2026.md")
        try write("design/ui-spec.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 2)
        for d in docs {
            XCTAssertEqual(d.kind, .generic)
        }
    }

    func testScansGitHubDirectory() throws {
        try write(".github/PULL_REQUEST_TEMPLATE.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].relativePath, ".github/PULL_REQUEST_TEMPLATE.md")
    }

    func testIgnoresNonDocExtensions() throws {
        try write("README.swift")    // 不是文档扩展名
        try write("CHANGELOG.json")  // 不是文档扩展名
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 0)
    }

    func testFindsTxtReadme() throws {
        try write("README.txt")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.kind, .readme)
    }

    // MARK: - docs/ 子目录

    func testFindsDocsSubdirectoryMdFiles() throws {
        try write("docs/architecture.md")
        try write("docs/api-spec.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 2)
        for d in docs {
            XCTAssertEqual(d.kind, .generic, "docs/ 下面的 md 都是 .generic")
            XCTAssertTrue(d.relativePath.hasPrefix("docs/"))
        }
    }

    func testFindsDocSubdirectoryFiles() throws {
        try write("doc/spec.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].relativePath, "doc/spec.md")
    }

    func testDoesNotRecurseBeyondMaxDepth() throws {
        // 现在 docs/ 递归 3 级（覆盖 docs/api/v1/file.md）。
        // 4 级（docs/a/b/c/file.md）应该跳过 —— 太深，噪音。
        try write("docs/a/b/c/too-deep.md")  // 4 级目录 —— 应跳过
        try write("docs/top.md")               // 1 级 —— 应找到
        try write("docs/sub/level2.md")        // 2 级 —— 应找到
        try write("docs/x/y/level3.md")        // 3 级 —— 应找到
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 3)
        XCTAssertNotNil(docs.first(where: { $0.name == "top.md" }))
        XCTAssertNotNil(docs.first(where: { $0.name == "level2.md" }))
        XCTAssertNotNil(docs.first(where: { $0.name == "level3.md" }))
        XCTAssertNil(docs.first(where: { $0.name == "too-deep.md" }))
    }

    // MARK: - 排序 + limit

    func testSortedByMtimeDescending() throws {
        try write("README.md", modifiedDaysAgo: 5)
        try write("TODO.md", modifiedDaysAgo: 1)     // 最新
        try write("CHANGELOG.md", modifiedDaysAgo: 10)
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.map(\.name), ["TODO.md", "README.md", "CHANGELOG.md"])
    }

    // MARK: - 极端

    func testEmptyRepo() {
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 0)
    }

    func testNonExistentRepo() {
        let docs = RepoDocsIndexer.index(repoPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        XCTAssertEqual(docs.count, 0)
    }

    func testRelativePathStripsRepoRoot() throws {
        try write("docs/api.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.first?.relativePath, "docs/api.md")
        XCTAssertFalse(docs.first?.relativePath.contains(tempDir.path) ?? true,
                       "relativePath 不应包含绝对路径")
    }

    // MARK: - lastViewedDate backward compat（一起测了）

    func testRepositoryDecodesWithoutLastViewedDate() throws {
        let oldJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "pathHash": "xyz",
          "path": "/tmp/v2-old",
          "name": "v2-old",
          "aheadCount": 0,
          "behindCount": 0,
          "uncommittedCount": 0,
          "lastFetchSuccess": false,
          "remotes": [],
          "defaultPushRemote": "origin",
          "isHidden": false,
          "customTags": [],
          "skipFetch": false,
          "skipMainBranchWarning": false,
          "falsePositiveMarks": [],
          "category": "unset",
          "hasReadme": true,
          "hasTests": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: oldJSON)
        XCTAssertNil(decoded.lastViewedDate, "缺失字段应默认 nil")
        XCTAssertEqual(decoded.category, .unset)
        XCTAssertTrue(decoded.hasReadme)
    }
}
