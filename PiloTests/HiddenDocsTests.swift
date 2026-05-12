import XCTest
@testable import Pilo

/// 文档在小邮局内"藏起来"功能：Repository.hiddenDocPaths Codable + backward compat。
final class HiddenDocsTests: XCTestCase {

    func testDefaultEmpty() {
        let r = Repository(path: "/tmp/x")
        XCTAssertTrue(r.hiddenDocPaths.isEmpty)
    }

    func testRoundTripPreservesHiddenSet() throws {
        let original = Repository(
            path: "/tmp/x",
            hiddenDocPaths: ["scratch.md", "old/draft.md", "v1/spec.md"]
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)
        XCTAssertEqual(decoded.hiddenDocPaths, original.hiddenDocPaths)
    }

    func testOldStateJSONDecodesWithEmptyHiddenSet() throws {
        // 模拟旧 state.json：完全没 hiddenDocPaths 字段
        let oldJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000003",
          "pathHash": "old-h",
          "path": "/tmp/v3-old",
          "name": "v3-old",
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
        XCTAssertTrue(decoded.hiddenDocPaths.isEmpty, "缺失字段应默认空 Set")
        XCTAssertEqual(decoded.name, "v3-old")
    }

    func testHiddenPathsAreSet() {
        // 用 Set 而不是 Array，确保去重
        var r = Repository(path: "/tmp/x")
        r.hiddenDocPaths.insert("a.md")
        r.hiddenDocPaths.insert("a.md")  // 重复
        r.hiddenDocPaths.insert("b.md")
        XCTAssertEqual(r.hiddenDocPaths.count, 2)
    }

    func testRemoveHiddenPath() {
        var r = Repository(path: "/tmp/x", hiddenDocPaths: ["a.md", "b.md"])
        r.hiddenDocPaths.remove("a.md")
        XCTAssertEqual(r.hiddenDocPaths, ["b.md"])
    }

    func testRoundTripWithMultipleNewFields() throws {
        // 一起测：category + lastViewedDate + hiddenDocPaths 同时 round-trip
        let original = Repository(
            path: "/tmp/full",
            category: .work,
            hasReadme: true,
            hasTests: true,
            lastViewedDate: Date(timeIntervalSince1970: 1_710_000_000),
            hiddenDocPaths: ["meeting-old.md"]
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)
        XCTAssertEqual(decoded.category, .work)
        XCTAssertTrue(decoded.hasReadme)
        XCTAssertEqual(decoded.lastViewedDate, original.lastViewedDate)
        XCTAssertEqual(decoded.hiddenDocPaths, ["meeting-old.md"])
    }
}
