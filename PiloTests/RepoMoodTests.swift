import XCTest
@testable import Pilo

/// Phase B (Project Inventory)：mood 派生 + category Codable 测试。
final class RepoMoodTests: XCTestCase {

    private func repo(daysAgo days: Double?) -> Repository {
        let lastCommit = days.map { Date().addingTimeInterval(-$0 * 86400) }
        return Repository(path: "/tmp/test", lastCommitDate: lastCommit)
    }

    func testMoodActiveWithinSevenDays() {
        XCTAssertEqual(repo(daysAgo: 0).mood, .active)
        XCTAssertEqual(repo(daysAgo: 3).mood, .active)
        XCTAssertEqual(repo(daysAgo: 6.5).mood, .active)
    }

    func testMoodIdleSevenToThirty() {
        XCTAssertEqual(repo(daysAgo: 7.5).mood, .idle)
        XCTAssertEqual(repo(daysAgo: 15).mood, .idle)
        XCTAssertEqual(repo(daysAgo: 29).mood, .idle)
    }

    func testMoodDyingThirtyToNinety() {
        XCTAssertEqual(repo(daysAgo: 30.5).mood, .dying)
        XCTAssertEqual(repo(daysAgo: 60).mood, .dying)
        XCTAssertEqual(repo(daysAgo: 89).mood, .dying)
    }

    func testMoodAbandonedNinetyPlus() {
        XCTAssertEqual(repo(daysAgo: 90.5).mood, .abandoned)
        XCTAssertEqual(repo(daysAgo: 180).mood, .abandoned)
        XCTAssertEqual(repo(daysAgo: 365).mood, .abandoned)
    }

    func testMoodNilLastCommitIsActive() {
        // 新建 repo 还没 commit → 默认 active，鼓励用户开始
        XCTAssertEqual(repo(daysAgo: nil).mood, .active)
    }

    func testDaysSinceLastCommit() {
        XCTAssertEqual(repo(daysAgo: 0).daysSinceLastCommit, 0)
        XCTAssertEqual(repo(daysAgo: 1.5).daysSinceLastCommit, 1)
        XCTAssertEqual(repo(daysAgo: 30).daysSinceLastCommit, 30)
        XCTAssertNil(repo(daysAgo: nil).daysSinceLastCommit)
    }

    // MARK: - Category 持久化

    func testCategoryDefaultsToUnset() {
        let r = Repository(path: "/tmp/x")
        XCTAssertEqual(r.category, .unset)
    }

    func testCategoryRoundTripWithRepository() throws {
        let original = Repository(
            path: "/tmp/x",
            category: .work,
            hasReadme: true,
            hasTests: false
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: data)
        XCTAssertEqual(decoded.category, .work)
        XCTAssertTrue(decoded.hasReadme)
        XCTAssertFalse(decoded.hasTests)
    }

    /// Backward-compat：旧 state.json 没有 Phase B 字段时，decode 必须用默认值兜底。
    func testOldStateJSONDecodesWithoutInventoryFields() throws {
        // 模拟一个旧 state.json：完全没 category / hasReadme / hasTests
        let oldJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "pathHash": "abc",
          "path": "/tmp/old",
          "name": "old",
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
          "falsePositiveMarks": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.pilo.decode(Repository.self, from: oldJSON)
        XCTAssertEqual(decoded.category, .unset, "缺失字段应默认 .unset")
        XCTAssertFalse(decoded.hasReadme, "缺失字段应默认 false")
        XCTAssertFalse(decoded.hasTests, "缺失字段应默认 false")
        XCTAssertEqual(decoded.name, "old", "旧字段应正常 decode")
    }

    func testRepoCategoryOrderedDisplay() {
        let order = RepoCategory.orderedDisplay
        XCTAssertEqual(order, [.work, .personal, .experiment, .unset])
    }
}
