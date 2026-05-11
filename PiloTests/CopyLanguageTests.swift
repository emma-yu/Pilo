import XCTest
@testable import Pilo

final class CopyLanguageTests: XCTestCase {

    // MARK: - Language enum 基础

    func testLanguageHasBothCases() {
        XCTAssertEqual(Language.allCases.count, 2)
        XCTAssertTrue(Language.allCases.contains(.zh))
        XCTAssertTrue(Language.allCases.contains(.en))
    }

    func testLanguageNativeNames() {
        XCTAssertEqual(Language.zh.nativeName, "简体中文")
        XCTAssertEqual(Language.en.nativeName, "English")
    }

    func testSystemDefaultIsSafe() {
        let def = Language.systemDefault
        // 至少不能崩；且必须是已知值
        XCTAssertTrue([Language.zh, Language.en].contains(def))
    }

    // MARK: - 关键文案 4 变体（zh×friendly / zh×minimal / en×friendly / en×minimal）

    func testMenubarAllSyncedAllFourVariants() {
        let zhF = Copy.menubarAllSynced(.friendly, .zh)
        let zhM = Copy.menubarAllSynced(.minimal, .zh)
        let enF = Copy.menubarAllSynced(.friendly, .en)
        let enM = Copy.menubarAllSynced(.minimal, .en)

        // 4 个都不为空
        for s in [zhF, zhM, enF, enM] {
            XCTAssertFalse(s.isEmpty, "字符串不应为空")
        }
        // 不同语言不重复
        XCTAssertNotEqual(zhF, enF, "中英文不应相同")
        XCTAssertNotEqual(zhM, enM)
        // friendly 比 minimal 更长（一般规律）
        XCTAssertGreaterThan(zhF.count, zhM.count)
        XCTAssertGreaterThan(enF.count, enM.count)

        // 中文友好版应包含温柔元素之一
        let zhFriendlyMarkers = ["啦", "呀", "～", "✨", "咕咕"]
        XCTAssertTrue(zhFriendlyMarkers.contains { zhF.contains($0) },
                      "中文 friendly 应有温柔标记之一")
        // 英文 friendly 应有 pigeon / friendly 标记之一
        let enFriendlyMarkers = ["Coo", "✨", "friend", "~"]
        XCTAssertTrue(enFriendlyMarkers.contains { enF.contains($0) },
                      "英文 friendly 应有 pigeon/friendly 标记")
    }

    func testPendingHeaderInterpolation() {
        let zhF = Copy.menubarPendingHeader(.friendly, .zh, count: 3)
        let enF = Copy.menubarPendingHeader(.friendly, .en, count: 3)
        XCTAssertTrue(zhF.contains("3"))
        XCTAssertTrue(enF.contains("3"))
        XCTAssertTrue(enF.contains("Coo"), "英文 friendly 应有 Coo")
    }

    func testOnboardingWelcomeBothLanguages() {
        let zh = Copy.Onboarding.welcomeTitle(.zh)
        let en = Copy.Onboarding.welcomeTitle(.en)
        XCTAssertEqual(zh, "咕咕～")
        XCTAssertEqual(en, "Coo coo~")
    }

    func testPushSuccessMessagingHasPigeonMetaphor() {
        let zhF = Copy.Push.successTitle(.friendly, .zh)
        let enF = Copy.Push.successTitle(.friendly, .en)
        // 中文应有"寄"或"送"或花朵；英文应有 deliver 或 fly 或 send
        let zhMarkers = ["寄", "送", "🌸", "啦"]
        let enMarkers = ["Delivered", "Sent", "Flew", "🌸"]
        XCTAssertTrue(zhMarkers.contains { zhF.contains($0) }, "中文成功态应有寄信 metaphor")
        XCTAssertTrue(enMarkers.contains { enF.contains($0) }, "英文成功态应有 delivery metaphor")
    }

    func testScanSectionHeaderClear() {
        let zhF = Copy.Scan.sectionHeader(.friendly, .zh, count: 0)
        let enF = Copy.Scan.sectionHeader(.friendly, .en, count: 0)
        let zhM = Copy.Scan.sectionHeader(.minimal, .zh, count: 0)
        let enM = Copy.Scan.sectionHeader(.minimal, .en, count: 0)

        XCTAssertTrue(zhF.contains("通过") || zhF.contains("✅"))
        XCTAssertTrue(enF.contains("clear") || enF.contains("✅"), "英文 clear 应含 'clear' 或 ✅")
        XCTAssertFalse(zhM.contains("✅"), "minimal 不应有 emoji")
        XCTAssertFalse(enM.contains("✅"))
    }

    // MARK: - 网络流行语避坑测试

    func testNoOutdatedSlangInChineseFriendly() {
        // 这些是 dating 严重的中文网络梗，不应出现
        let bannedZh = ["yyds", "绝绝子", "家人们", "awsl", "OK 的兄弟们"]
        let samples = [
            Copy.menubarAllSynced(.friendly, .zh),
            Copy.menubarPendingHeader(.friendly, .zh, count: 3),
            Copy.menubarScanInProgress(.friendly, .zh),
            Copy.menubarOffline(.friendly, .zh),
            Copy.emptyNoRepos(.friendly, .zh),
            Copy.Onboarding.welcomeBody(.zh),
            Copy.Push.successTitle(.friendly, .zh),
        ]
        for sample in samples {
            for banned in bannedZh {
                XCTAssertFalse(sample.lowercased().contains(banned.lowercased()),
                              "中文 friendly 含已过气网络梗 '\(banned)' 在：\(sample)")
            }
        }
    }

    func testNoCringeSlangInEnglishFriendly() {
        // 易显业余 / 性别假设 / 文化挪用的英文 slang
        let bannedEn = ["uwu", "owo", "no cap", "fr fr", "tbh", "imo", "girlies",
                        "kawaii", "based", "lol", "omg"]
        let samples = [
            Copy.menubarAllSynced(.friendly, .en),
            Copy.menubarPendingHeader(.friendly, .en, count: 3),
            Copy.menubarScanInProgress(.friendly, .en),
            Copy.menubarOffline(.friendly, .en),
            Copy.emptyNoRepos(.friendly, .en),
            Copy.Onboarding.welcomeBody(.en),
            Copy.Push.successTitle(.friendly, .en),
            Copy.Scan.sectionHeader(.friendly, .en, count: 2),
        ]
        for sample in samples {
            let lower = sample.lowercased()
            for banned in bannedEn {
                XCTAssertFalse(lower.contains(banned),
                              "英文 friendly 含 cringe slang '\(banned)' 在：\(sample)")
            }
        }
    }

    func testCriticalContentNotJokey() {
        // 关键安全文案不应有 emoji 或感叹号过多
        let bypass = Copy.Scan.bypassConfirmDesc
        XCTAssertFalse(bypass.contains("lol"), "bypass 文案不应含 lol")
        XCTAssertFalse(bypass.contains("😂"), "bypass 文案不应含 笑 emoji")
        // 应包含建议关键词
        XCTAssertTrue(bypass.contains("revoke") || bypass.contains("重新生成") || bypass.contains(".env"),
                      "bypass 文案应给出实际建议")
    }
}
