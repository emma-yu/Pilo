import XCTest
@testable import Pilo

final class RepositoryCodableTests: XCTestCase {

    func testRepositoryRoundTrip() throws {
        let original = Repository(
            path: "/Users/test/Code/example",
            currentBranch: "main",
            aheadCount: 2,
            behindCount: 1,
            uncommittedCount: 3,
            lastCommitDate: Date(timeIntervalSince1970: 1_700_000_000),
            remotes: [
                GitRemote(name: "origin", url: "git@github.com:test/example.git", isPublic: nil),
                GitRemote(name: "upstream", url: "https://github.com/team/example.git", isPublic: nil),
            ],
            firstCommitHash: "abc123def456"
        )

        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)

        XCTAssertEqual(original.path, decoded.path)
        XCTAssertEqual(original.pathHash, decoded.pathHash, "pathHash 必须一致")
        XCTAssertEqual(original.currentBranch, decoded.currentBranch)
        XCTAssertEqual(original.aheadCount, decoded.aheadCount)
        XCTAssertEqual(original.behindCount, decoded.behindCount)
        XCTAssertEqual(original.uncommittedCount, decoded.uncommittedCount)
        XCTAssertEqual(original.remotes.count, decoded.remotes.count)
        XCTAssertEqual(original.firstCommitHash, decoded.firstCommitHash)
    }

    func testPathHashStable() {
        let h1 = Repository.hash(path: "/Users/test/Code/example")
        let h2 = Repository.hash(path: "/Users/test/Code/example")
        XCTAssertEqual(h1, h2, "同一 path 必须产生同一 hash")
        XCTAssertEqual(h1.count, 64, "SHA256 hex 必须是 64 字符")

        let h3 = Repository.hash(path: "/Users/test/Code/example2")
        XCTAssertNotEqual(h1, h3)
    }

    func testRepositoryStoreWithVersion() throws {
        let repos = [
            Repository(path: "/a"),
            Repository(path: "/b"),
        ]
        let store = RepositoryStore(version: RepositoryStore.currentVersion, repositories: repos)
        let data = try JSONEncoder.pilo.encode(store)
        let decoded = try JSONDecoder.pilo.decode(RepositoryStore.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.repositories.count, 2)
    }

    func testStatusSummary() {
        var repo = Repository(path: "/x")
        XCTAssertEqual(repo.statusSummary, .synced)

        repo.aheadCount = 1
        XCTAssertEqual(repo.statusSummary, .ahead)

        repo.uncommittedCount = 2
        XCTAssertEqual(repo.statusSummary, .uncommitted,
                       "uncommitted 优先级应高于 ahead")
    }

    func testGitRemoteDisplayHost() {
        let r1 = GitRemote(name: "origin", url: "git@github.com:emma/pilo.git", isPublic: nil)
        XCTAssertEqual(r1.displayHost, "github.com/emma/pilo")

        let r2 = GitRemote(name: "origin", url: "https://github.com/emma/pilo.git", isPublic: nil)
        XCTAssertEqual(r2.displayHost, "github.com/emma/pilo")
    }

    // MARK: - 凭证脱敏（P0 安全）

    func testHTTPSWithPATIsSanitized() {
        let dirty = "https://emma-yu:ghp_FAKETOKEN1234567890@github.com/emma-yu/foo.git"
        let r = GitRemote(name: "origin", url: dirty)
        XCTAssertFalse(r.url.contains("ghp_"), "url 字段不能保留 PAT")
        XCTAssertFalse(r.url.contains("emma-yu:"), "url 字段不能保留 user:pass")
        XCTAssertEqual(r.url, "https://github.com/emma-yu/foo.git")
    }

    func testHTTPSWithUserOnlyIsSanitized() {
        let dirty = "https://emma-yu@github.com/foo.git"
        let r = GitRemote(name: "origin", url: dirty)
        XCTAssertEqual(r.url, "https://github.com/foo.git")
    }

    func testSSHFormUnchanged() {
        let ssh = "git@github.com:emma/foo.git"
        let r = GitRemote(name: "origin", url: ssh)
        XCTAssertEqual(r.url, ssh, "SSH 形式不带凭证，原样保留")
    }

    func testSanitizeAppliedOnDecode() throws {
        // 模拟旧 state.json 里残留的脏 URL 被读回
        let dirtyJSON = """
        {"name":"origin","url":"https://x:ghp_LEAK1234567890@github.com/a/b.git"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder.pilo.decode(GitRemote.self, from: dirtyJSON)
        XCTAssertFalse(decoded.url.contains("ghp_"), "decode 后必须也脱敏")
        XCTAssertFalse(decoded.url.contains("x:"), "decode 后必须也脱敏")
    }

    // MARK: - Commit 通知字段向后兼容

    func testCommitNotificationFieldsRoundTrip() throws {
        let original = Repository(
            path: "/Users/test/Code/example",
            latestCommitHash: "abc1234",
            lastNotifiedCommitHash: "def5678"
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)
        XCTAssertEqual(decoded.latestCommitHash, "abc1234")
        XCTAssertEqual(decoded.lastNotifiedCommitHash, "def5678")
    }

    // MARK: - AI 工具配置（Phase C）向后兼容

    func testAIToolsDetectedRoundTrip() throws {
        let original = Repository(
            path: "/Users/test/Code/example",
            aiToolsDetected: [.claudeCode, .cursor]
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)
        XCTAssertEqual(decoded.aiToolsDetected, Set([.claudeCode, .cursor]))
    }

    func testLegacyStateJSONWithoutAIToolsDetected() throws {
        // 模拟 Phase C 之前的 state.json：没有 aiToolsDetected 字段
        // —— 必须能 decode + 默认空集
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000003",
          "pathHash": "xyz",
          "path": "/x",
          "name": "x",
          "aheadCount": 0,
          "behindCount": 0,
          "uncommittedCount": 0,
          "lastFetchSuccess": false,
          "remotes": [],
          "defaultPushRemote": "origin",
          "isHidden": false,
          "customTags": [],
          "lastScanDate": "2026-01-01T00:00:00Z",
          "skipFetch": false,
          "skipMainBranchWarning": false,
          "falsePositiveMarks": [],
          "category": "unset",
          "hasReadme": false,
          "hasTests": false,
          "hiddenDocPaths": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: legacyJSON)
        XCTAssertTrue(decoded.aiToolsDetected.isEmpty,
                      "旧 state.json 没有该字段 → 必须 fallback 到空集")
    }

    func testLegacyStateJSONWithoutNotificationFields() throws {
        // 模拟旧版 state.json：完全没有 latestCommitHash / lastNotifiedCommitHash
        // —— decode 必须不抛错，两个字段 fallback 为 nil
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "pathHash": "abc",
          "path": "/x",
          "name": "x",
          "aheadCount": 0,
          "behindCount": 0,
          "uncommittedCount": 0,
          "lastFetchSuccess": false,
          "remotes": [],
          "defaultPushRemote": "origin",
          "isHidden": false,
          "customTags": [],
          "lastScanDate": "2026-01-01T00:00:00Z",
          "skipFetch": false,
          "skipMainBranchWarning": false,
          "falsePositiveMarks": [],
          "category": "unset",
          "hasReadme": false,
          "hasTests": false,
          "hiddenDocPaths": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: legacyJSON)
        XCTAssertNil(decoded.latestCommitHash, "旧 state.json fallback → nil")
        XCTAssertNil(decoded.lastNotifiedCommitHash, "旧 state.json fallback → nil")
    }
}
