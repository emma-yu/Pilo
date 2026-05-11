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

    func testIgnoresRandomMdAtRoot() throws {
        // 根级 md 不命中 prefix 表 → 不算文档
        try write("scratch.md")
        try write("ideas-list.md")  // ideas 在 prefixes 里 → notes
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].kind, .notes)
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

    func testDoesNotRecurseDeeperThanDocsOneLevel() throws {
        try write("docs/sub/deep.md")  // 二级深 —— 不扫
        try write("docs/top.md")
        let docs = RepoDocsIndexer.index(repoPath: tempDir.path)
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs[0].name, "top.md")
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
