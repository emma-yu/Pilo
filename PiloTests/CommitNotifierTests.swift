import XCTest
@testable import Pilo

/// CommitNotifier 单测：聚焦 throttle / coalesce / 文案，
/// **不**走真 UNUserNotificationCenter（dryRun = true 拦截）
final class CommitNotifierTests: XCTestCase {

    private var originalLanguage: String?

    override func setUp() {
        super.setUp()
        originalLanguage = UserDefaults.standard.string(forKey: SettingsKey.language.rawValue)
        UserDefaults.standard.set("zh", forKey: SettingsKey.language.rawValue)
    }

    override func tearDown() {
        if let original = originalLanguage {
            UserDefaults.standard.set(original, forKey: SettingsKey.language.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: SettingsKey.language.rawValue)
        }
        super.tearDown()
    }

    private func makeCommit(_ hash: String, _ subject: String) -> CommitSummary {
        CommitSummary(
            hash: hash,
            subject: subject,
            date: Date(),
            author: "Emma"
        )
    }

    // MARK: - 不在 enabled 状态 → no-op（核心安全保证）

    func testDisabledByDefault() async {
        let n = CommitNotifier(coalesceWindow: 0.1, dryRun: true)
        await n.enqueue(
            repoId: UUID(),
            repoName: "pilo",
            latestHash: "abc",
            commits: [makeCommit("abc", "feat: x")]
        )
        let pending = await n.pendingCountForTest
        XCTAssertEqual(pending, 0, "默认 OFF —— 必须 no-op，不能偷偷攒任务")
    }

    // MARK: - 合并窗口：60s 内多次 enqueue 合并成一次

    func testCoalesceWithinWindow() async {
        let n = CommitNotifier(coalesceWindow: 60, dryRun: true)
        _ = await n.enable()

        let repoId = UUID()
        await n.enqueue(
            repoId: repoId, repoName: "pilo", latestHash: "h1",
            commits: [makeCommit("h1", "first commit")]
        )
        await n.enqueue(
            repoId: repoId, repoName: "pilo", latestHash: "h2",
            commits: [makeCommit("h2", "second commit")]
        )
        await n.enqueue(
            repoId: repoId, repoName: "pilo", latestHash: "h3",
            commits: [makeCommit("h3", "third commit")]
        )

        let pendingCount = await n.pendingCommits(repoId: repoId)
        XCTAssertEqual(pendingCount, 3, "60s 内三次 enqueue 必须合并到一个 batch（3 commits）")

        // 立即 flush —— 模拟窗口结束
        await n.flushAllForTest()

        let delivered = await n.deliveredForTest
        XCTAssertEqual(delivered.count, 1, "合并后只能投递 1 次通知，不能 3 次")
        XCTAssertTrue(delivered[0].body.contains("等 3 封"), "body 应该说『等 N 封』")
    }

    // MARK: - 不同 repo 不合并

    func testDifferentReposDoNotCoalesce() async {
        let n = CommitNotifier(coalesceWindow: 60, dryRun: true)
        _ = await n.enable()

        let repoA = UUID()
        let repoB = UUID()

        await n.enqueue(
            repoId: repoA, repoName: "pilo", latestHash: "ha",
            commits: [makeCommit("ha", "A commit")]
        )
        await n.enqueue(
            repoId: repoB, repoName: "letters", latestHash: "hb",
            commits: [makeCommit("hb", "B commit")]
        )

        let pendingCount = await n.pendingCountForTest
        XCTAssertEqual(pendingCount, 2, "不同 repo 必须各自独立攒")

        await n.flushAllForTest()

        let delivered = await n.deliveredForTest
        XCTAssertEqual(delivered.count, 2, "两个 repo → 两条独立通知")
    }

    // MARK: - 单条 commit 文案

    func testSingleCommitBody() {
        let body = CommitNotifier.bodyText(commits: [
            CommitSummary(hash: "abc", subject: "fix: 修一个 bug", date: Date(), author: "Emma")
        ])
        XCTAssertEqual(body, "fix: 修一个 bug")
        XCTAssertFalse(body.contains("等"), "单条不应有『等 N 封』后缀")
    }

    // MARK: - 多条 commit 文案

    func testMultipleCommitsBody() {
        let body = CommitNotifier.bodyText(commits: [
            CommitSummary(hash: "abc", subject: "feat: 新功能", date: Date(), author: "Emma"),
            CommitSummary(hash: "def", subject: "test: 加测试",  date: Date(), author: "Emma"),
        ])
        XCTAssertTrue(body.contains("feat: 新功能"), "应展示第一条 subject")
        XCTAssertTrue(body.contains("等 2 封"), "应说『等 2 封』")
        XCTAssertFalse(body.contains("test:"), "第二条不展开，太长会被截")
    }

    // MARK: - 标题：单条 vs 多条

    func testTitleSingle() {
        let t = CommitNotifier.titleText(count: 1, repoName: "pilo")
        XCTAssertTrue(t.contains("pilo"))
        XCTAssertTrue(t.contains("一条"))
        XCTAssertTrue(t.contains("新消息"))
    }

    func testTitleMultiple() {
        let t = CommitNotifier.titleText(count: 5, repoName: "pilo")
        XCTAssertTrue(t.contains("pilo"))
        XCTAssertTrue(t.contains("5 条"))
        XCTAssertTrue(t.contains("新消息"))
    }

    // MARK: - disable 清理

    func testDisableClearsPending() async {
        let n = CommitNotifier(coalesceWindow: 60, dryRun: true)
        _ = await n.enable()

        await n.enqueue(
            repoId: UUID(), repoName: "pilo", latestHash: "h",
            commits: [makeCommit("h", "x")]
        )

        let before = await n.pendingCountForTest
        XCTAssertEqual(before, 1)

        await n.disable()

        let after = await n.pendingCountForTest
        XCTAssertEqual(after, 0, "disable 必须清空 pending —— 避免重新 enable 后老消息泄露")
    }

    // MARK: - 空 commits 不入队

    func testEmptyCommitsNoOp() async {
        let n = CommitNotifier(coalesceWindow: 60, dryRun: true)
        _ = await n.enable()
        await n.enqueue(
            repoId: UUID(), repoName: "pilo", latestHash: "h", commits: []
        )
        let pending = await n.pendingCountForTest
        XCTAssertEqual(pending, 0)
    }

    // MARK: - 英文通知测试

    func testEnglishNotifierTitleAndBody() {
        UserDefaults.standard.set("en", forKey: SettingsKey.language.rawValue)

        let titleSingle = CommitNotifier.titleText(count: 1, repoName: "pilo")
        XCTAssertEqual(titleSingle, "pilo · 1 new message")

        let titleMultiple = CommitNotifier.titleText(count: 3, repoName: "pilo")
        XCTAssertEqual(titleMultiple, "pilo · 3 new messages")

        let bodySingle = CommitNotifier.bodyText(commits: [
            CommitSummary(hash: "abc", subject: "fix: resolve a bug", date: Date(), author: "Emma")
        ])
        XCTAssertEqual(bodySingle, "fix: resolve a bug")

        let bodyMultiple = CommitNotifier.bodyText(commits: [
            CommitSummary(hash: "abc", subject: "feat: add feature", date: Date(), author: "Emma"),
            CommitSummary(hash: "def", subject: "chore: clean code", date: Date(), author: "Emma")
        ])
        XCTAssertTrue(bodyMultiple.contains("feat: add feature"))
        XCTAssertTrue(bodyMultiple.contains("and 1 more"))
    }
}
