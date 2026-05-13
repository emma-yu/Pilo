import XCTest
@testable import Pilo

/// Resume.subtitle 4-tier 智能 fallback 单测：
///   P1 actionable (uncommitted / pending)
///   P2 1-29 天
///   P3 30+ 天
///   P4 cleanup fallback
///
/// 旧版总是 "今天见过 · 在 main"（tautology + 重复 path 行），这套测试
/// 顺便守卫"不再回到那个 dumb 文案"
final class ResumeSubtitleTests: XCTestCase {

    // MARK: - P1 actionable

    func testActionableBothUncommittedAndPending_zh() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 5,
            pendingPushCount: 3,
            daysSinceViewed: 0,
            branch: "main",
            .friendly,
            .zh
        )
        XCTAssertTrue(s.contains("桌上 5 件"))
        XCTAssertTrue(s.contains("待寄 3 个"))
        XCTAssertFalse(s.contains("今天见过"), "禁止回退到 tautology 文案")
        XCTAssertFalse(s.contains("在 main"), "actionable 档不该再 echo branch（path 行已有）")
    }

    func testActionableUncommittedOnly_zh() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 4,
            pendingPushCount: 0,
            daysSinceViewed: 2,
            branch: "main",
            .friendly,
            .zh
        )
        XCTAssertTrue(s.contains("桌上"))
        XCTAssertTrue(s.contains("4"))
        XCTAssertFalse(s.contains("天前"), "actionable 高优先级 —— 不该退化到时间感")
    }

    func testActionablePendingOnly_zh() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0,
            pendingPushCount: 8,
            daysSinceViewed: nil,
            branch: "main",
            .friendly,
            .zh
        )
        XCTAssertTrue(s.contains("8"))
        XCTAssertTrue(s.contains("等着寄出"))
    }

    func testActionableUncommittedOnly_en_pluralization() {
        let single = Copy.Resume.subtitle(
            uncommittedCount: 1, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .friendly, .en
        )
        XCTAssertEqual(single, "1 draft on the desk")

        let plural = Copy.Resume.subtitle(
            uncommittedCount: 3, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .friendly, .en
        )
        XCTAssertEqual(plural, "3 drafts on the desk")
    }

    func testActionableMinimalTone_zh() {
        // minimal 模式应该砍掉 emotional 包装词
        let s = Copy.Resume.subtitle(
            uncommittedCount: 5, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .minimal, .zh
        )
        XCTAssertFalse(s.contains("桌上"), "minimal 不带 postal flavor 词")
        XCTAssertTrue(s.contains("5"))
        XCTAssertTrue(s.contains("未提交"))
    }

    // MARK: - P2 1-29 天

    func testRecentAbsenceYesterday_zh() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 1, branch: "main",
            .friendly, .zh
        )
        XCTAssertEqual(s, "昨天来过")
        XCTAssertFalse(s.contains("1 天前"), "昨天应该用『昨天』而不是『1 天前』")
    }

    func testRecentAbsenceDays_zh() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 5, branch: "main",
            .friendly, .zh
        )
        XCTAssertEqual(s, "上次见你是 5 天前")
        XCTAssertFalse(s.contains("在 main"), "P2 不该再 echo branch")
    }

    func testRecentAbsenceDays_en() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 5, branch: "main",
            .friendly, .en
        )
        XCTAssertEqual(s, "Last seen 5 days ago")
    }

    // MARK: - P3 30+ 天

    func testLongAbsence_zh_friendly() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 45, branch: "main",
            .friendly, .zh
        )
        XCTAssertTrue(s.contains("45 天"))
        XCTAssertTrue(s.contains("欢迎回来"), "长别离档 friendly 应带感情色彩")
    }

    func testLongAbsence_zh_minimal() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 45, branch: "main",
            .minimal, .zh
        )
        XCTAssertTrue(s.contains("45"))
        XCTAssertFalse(s.contains("欢迎回来"), "minimal 模式砍掉感情包装")
    }

    func testLongAbsenceBoundary30Days() {
        // 边界：恰好 30 天应走 P3，不应走 P2
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 30, branch: nil,
            .friendly, .zh
        )
        XCTAssertTrue(s.contains("欢迎回来"))
    }

    // MARK: - P4 cleanup fallback

    func testCleanState_zh_friendly() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .friendly, .zh
        )
        XCTAssertEqual(s, "在 main · 一切都好")
        XCTAssertFalse(s.contains("今天见过"), "禁止回退到 tautology")
    }

    func testCleanState_zh_minimal() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .minimal, .zh
        )
        XCTAssertEqual(s, "main · 已同步")
    }

    func testCleanState_en_friendly() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 0, branch: "main",
            .friendly, .en
        )
        XCTAssertEqual(s, "on main · all clear")
    }

    func testCleanStateNoBranch() {
        // detached HEAD 等情况：branch nil 时不渲染 branch 前缀
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: 0, branch: nil,
            .friendly, .zh
        )
        XCTAssertEqual(s, "一切都好")
        XCTAssertFalse(s.contains("·"))
    }

    // MARK: - 首次见面 (firstTime → daysSinceViewed nil)

    func testFirstTimeWithWork_fallsToActionable() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 3, pendingPushCount: 0,
            daysSinceViewed: nil, branch: "main",
            .friendly, .zh
        )
        XCTAssertTrue(s.contains("桌上"))
        XCTAssertTrue(s.contains("3"))
    }

    func testFirstTimeNoWork_fallsToCleanState() {
        let s = Copy.Resume.subtitle(
            uncommittedCount: 0, pendingPushCount: 0,
            daysSinceViewed: nil, branch: "main",
            .friendly, .zh
        )
        XCTAssertEqual(s, "在 main · 一切都好")
    }

    // MARK: - Regression guard

    func testNeverProducesOldTautology() {
        // 全面遍历常见 days 值，确保永远不再出现"今天见过"
        for days in [0, 1, 2, 7, 14, 29, 30, 90, 365] {
            for lang in [Language.zh, .en] {
                for tone in [Tone.friendly, .minimal] {
                    let s = Copy.Resume.subtitle(
                        uncommittedCount: 0, pendingPushCount: 0,
                        daysSinceViewed: days, branch: "main",
                        tone, lang
                    )
                    XCTAssertFalse(
                        s.contains("今天见过"),
                        "日 \(days) tone \(tone) lang \(lang) 不应包含旧 tautology 文案"
                    )
                    XCTAssertFalse(
                        s.contains("Seen earlier today"),
                        "日 \(days) tone \(tone) lang \(lang) 不应包含旧 en 文案"
                    )
                }
            }
        }
    }
}
