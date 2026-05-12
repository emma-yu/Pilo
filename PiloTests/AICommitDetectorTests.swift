import XCTest
@testable import Pilo

/// S1 AI Push Guard：AICommitDetector 启发式测试。
/// 保守是关键 —— 宁可漏标也不要错标人类 commit。
final class AICommitDetectorTests: XCTestCase {

    // MARK: - 单信号 → maybeAI

    func testNoreplyAuthorEmailMaybeAI() {
        let r = AICommitDetector.detect(
            author: "Claude",
            authorEmail: "noreply@anthropic.com",
            subject: "fix typo",
            changedFileCount: 1
        )
        XCTAssertEqual(r, .maybeAI, "noreply 邮箱单信号 → maybeAI")
    }

    func testGenericSubjectMaybeAI() {
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: "emma@personal.com",
            subject: "WIP",
            changedFileCount: 3
        )
        XCTAssertEqual(r, .maybeAI)
    }

    func testManyFilesMaybeAI() {
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: "emma@personal.com",
            subject: "refactor auth module",
            changedFileCount: 20
        )
        XCTAssertEqual(r, .maybeAI, "改 ≥15 文件单信号 → maybeAI")
    }

    func testCoAuthoredByClaude() {
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: "emma@x.com",
            subject: "Add reminder flow\n\nCo-Authored-By: Claude",
            changedFileCount: 4
        )
        XCTAssertEqual(r, .maybeAI)
    }

    // MARK: - 多信号 → likelyAI

    func testNoreplyPlusGenericLikelyAI() {
        let r = AICommitDetector.detect(
            author: "Claude",
            authorEmail: "noreply@anthropic.com",
            subject: "updated files",
            changedFileCount: 5
        )
        XCTAssertEqual(r, .likelyAI, "两个信号叠加 → likelyAI")
    }

    func testNoreplyPlusManyFilesLikelyAI() {
        let r = AICommitDetector.detect(
            author: "Cursor Agent",
            authorEmail: "noreply@cursor.so",
            subject: "Refactor module",
            changedFileCount: 25
        )
        XCTAssertEqual(r, .likelyAI)
    }

    func testThreeSignalsStillLikelyAI() {
        let r = AICommitDetector.detect(
            author: "Bot",
            authorEmail: "noreply@anthropic.com",
            subject: "updated files",
            changedFileCount: 30
        )
        XCTAssertEqual(r, .likelyAI)
    }

    // MARK: - 零信号 → unknown

    func testHumanCommitIsUnknown() {
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: "emma@gmail.com",
            subject: "fix race condition in token refresh",
            changedFileCount: 3
        )
        XCTAssertEqual(r, .unknown, "正常人类 commit 应保持 unknown")
    }

    func testRefactorBy人类NotFlagged() {
        // 14 文件刚好低于阈值 + specific subject
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: "emma@gmail.com",
            subject: "Migrate from old auth API to new session-based flow",
            changedFileCount: 14
        )
        XCTAssertEqual(r, .unknown, "14 文件 + specific subject 不该被标")
    }

    func testEmptySubjectIsUnknownNotCrash() {
        let r = AICommitDetector.detect(
            author: "Emma",
            authorEmail: nil,
            subject: "",
            changedFileCount: 0
        )
        XCTAssertEqual(r, .unknown)
    }

    // MARK: - 边界

    func testFileCountBoundary() {
        // 14 不命中信号
        XCTAssertEqual(
            AICommitDetector.detect(author: "x", authorEmail: nil, subject: "specific subject here", changedFileCount: 14),
            .unknown
        )
        // 15 命中信号
        XCTAssertEqual(
            AICommitDetector.detect(author: "x", authorEmail: nil, subject: "specific subject here", changedFileCount: 15),
            .maybeAI
        )
    }

    func testBotEmailMaybeAI() {
        let r = AICommitDetector.detect(
            author: "dependabot[bot]",
            authorEmail: "49699333+dependabot[bot]@users.noreply.github.com",
            subject: "Bump foo from 1.0 to 1.1",
            changedFileCount: 2
        )
        XCTAssertEqual(r, .maybeAI, "[bot] suffix 应该被识别")
    }
}
