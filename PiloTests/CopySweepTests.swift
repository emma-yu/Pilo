import XCTest
@testable import Pilo

/// 锁定 i18n 完整性：critical 流程文案必须有 en 变体且不能漏到中文。
final class CopySweepTests: XCTestCase {

    // MARK: - Bypass dialog

    func testBypassConfirmHasEnglish() {
        let zh = Copy.Scan.bypassConfirmDesc(.zh)
        let en = Copy.Scan.bypassConfirmDesc(.en)
        XCTAssertNotEqual(zh, en)
        let lower = en.lowercased()
        XCTAssertTrue(lower.contains("revoke") || lower.contains("rotat"),
                      "EN bypass desc 应含 revoke/rotate 关键词")
    }

    func testBypassConfirmButtonsBothLanguages() {
        XCTAssertEqual(Copy.Scan.bypassConfirmYes(.en), "I understand, push")
        XCTAssertEqual(Copy.Scan.bypassConfirmNo(.en),  "Cancel")
        XCTAssertEqual(Copy.Scan.bypassNameMismatch(.en), "Repo name doesn't match")
    }

    // MARK: - FP scope sheet

    func testFalsePositiveScopeAllBilingual() {
        XCTAssertEqual(Copy.Scan.markFPTitle(.en), "How to mark?")
        XCTAssertEqual(Copy.Scan.markFPHere(.en),  "Just this file")
        XCTAssertEqual(Copy.Scan.markFPRule(.en),  "Skip this rule for the whole repo")
        XCTAssertEqual(Copy.Scan.markFPCancel(.en), "Hold on")
        // 中文版仍存在且不为空
        XCTAssertFalse(Copy.Scan.markFPTitle(.zh).isEmpty)
        XCTAssertFalse(Copy.Scan.markFPHere(.zh).isEmpty)
    }

    // MARK: - Settings KillSwitch

    func testKillSwitchSettingsBothLanguages() {
        let zh = Copy.KillSwitch.settingsKillSwitchDesc(.zh)
        let en = Copy.KillSwitch.settingsKillSwitchDesc(.en)
        XCTAssertNotEqual(zh, en)
        XCTAssertTrue(en.contains("Pause") || en.contains("restore"))
        XCTAssertEqual(Copy.KillSwitch.settingsKillSwitchRestoreButton(.en), "Restore now")
        XCTAssertEqual(Copy.KillSwitch.settingsKillSwitchActivateButton(.en), "Pause for 24 hours")
    }

    // MARK: - GitHub visibility URL 解析

    func testParseOwnerRepoHTTPS() {
        let or = GitHubVisibilityClient.parseOwnerRepo(from: "https://github.com/emma/foo.git")
        XCTAssertEqual(or?.owner, "emma")
        XCTAssertEqual(or?.repo, "foo")
    }

    func testParseOwnerRepoSSH() {
        let or = GitHubVisibilityClient.parseOwnerRepo(from: "git@github.com:emma/foo.git")
        XCTAssertEqual(or?.owner, "emma")
        XCTAssertEqual(or?.repo, "foo")
    }

    func testParseOwnerRepoNoSuffix() {
        let or = GitHubVisibilityClient.parseOwnerRepo(from: "https://github.com/emma/foo")
        XCTAssertEqual(or?.owner, "emma")
        XCTAssertEqual(or?.repo, "foo")
    }

    func testParseOwnerRepoNonGitHubReturnsNil() {
        XCTAssertNil(GitHubVisibilityClient.parseOwnerRepo(from: "git@gitlab.com:emma/foo.git"))
        XCTAssertNil(GitHubVisibilityClient.parseOwnerRepo(from: "https://bitbucket.org/x/y"))
    }
}
