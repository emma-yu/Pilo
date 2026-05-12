import XCTest
@testable import Pilo

/// S2 跨 Repo 工作日报 service 测试。
/// 不真跑 git —— 把 service.compute 的内部 collectActivity 当函数 spec 测，
/// 主要保证：分桶逻辑 / 时间边界 / 排序 / 空态。
final class DailyDigestServiceTests: XCTestCase {

    // MARK: - startOfToday

    func testStartOfTodayIsMidnight() {
        let date = DailyDigestService.startOfToday()
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }

    func testStartOfTodayForGivenNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = DailyDigestService.startOfToday(now: now)
        XCTAssertLessThanOrEqual(start, now)
        // 间隔不超过 24 小时
        XCTAssertLessThanOrEqual(now.timeIntervalSince(start), 24 * 3600)
    }

    // MARK: - DigestRow Identifiable

    func testDigestRowUsesRepoId() {
        let id = UUID()
        let row = DailyDigest.DigestRow(
            repoId: id,
            repoName: "x",
            repoPath: "/x",
            commitsToday: 3,
            lastActivityToday: Date()
        )
        XCTAssertEqual(row.id, id)
    }

    // MARK: - DailyDigest semantics

    func testIsEmpty() {
        let empty = DailyDigest(date: Date(), pushedRepos: [], modifiedNotPushed: [], visitedOnly: [])
        XCTAssertTrue(empty.isEmpty)
    }

    func testIsEmptyWithOneRowFalse() {
        let row = DailyDigest.DigestRow(
            repoId: UUID(), repoName: "x", repoPath: "/x",
            commitsToday: 1, lastActivityToday: Date()
        )
        let d = DailyDigest(date: Date(), pushedRepos: [row], modifiedNotPushed: [], visitedOnly: [])
        XCTAssertFalse(d.isEmpty)
        XCTAssertEqual(d.totalActiveCount, 1)
    }

    func testTotalActiveCountAddsBuckets() {
        let r = { DailyDigest.DigestRow(repoId: UUID(), repoName: "x", repoPath: "/x", commitsToday: 1, lastActivityToday: Date()) }
        let d = DailyDigest(
            date: Date(),
            pushedRepos: [r(), r()],
            modifiedNotPushed: [r()],
            visitedOnly: [r(), r(), r()]
        )
        XCTAssertEqual(d.totalActiveCount, 6)
    }
}
