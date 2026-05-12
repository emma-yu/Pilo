import XCTest
@testable import Pilo

/// 用真实 git push 失败的 stderr 字符串校验分类器。
/// 这些 stderr 都是 git 在 macOS 上常见的输出，不依赖网络。
final class PushOutcomeTests: XCTestCase {

    private func result(_ stderr: String, exit: Int32 = 1) -> GitClient.ProcessResult {
        GitClient.ProcessResult(stdout: "", stderr: stderr, exitCode: exit)
    }

    // MARK: - 成功

    func testSuccessIsSuccess() {
        let r = GitClient.ProcessResult(stdout: "To github.com:emma/x.git\n   abc..def main -> main\n", stderr: "", exitCode: 0)
        let o = PushExecutor.classify(result: r, commitCount: 2)
        if case .success(let n) = o {
            XCTAssertEqual(n, 2)
        } else {
            XCTFail("应该是 success，实际：\(o)")
        }
    }

    // MARK: - Authentication

    func testHTTPSAuthFailedDetected() {
        let stderr = """
        remote: Support for password authentication was removed on August 13, 2021.
        remote: Please see https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls for information on currently recommended modes of authentication.
        fatal: Authentication failed for 'https://github.com/emma/foo.git/'
        """
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .authenticationFailed = o { /* ok */ } else { XCTFail("期望 authenticationFailed，实际 \(o)") }
    }

    func testSSHKeyDeniedDetected() {
        let stderr = "git@github.com: Permission denied (publickey).\nfatal: Could not read from remote repository."
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .authenticationFailed = o { /* ok */ } else { XCTFail("期望 authenticationFailed，实际 \(o)") }
    }

    func testTerminalPromptsDisabledDetected() {
        let stderr = "fatal: could not read Username for 'https://github.com': terminal prompts disabled"
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .authenticationFailed = o { /* ok */ } else { XCTFail("期望 authenticationFailed，实际 \(o)") }
    }

    // MARK: - Non-fast-forward

    func testNonFastForwardDetected() {
        let stderr = """
        To github.com:emma/foo.git
         ! [rejected]        main -> main (non-fast-forward)
        error: failed to push some refs to 'github.com:emma/foo.git'
        hint: Updates were rejected because the tip of your current branch is behind
        hint: its remote counterpart. Integrate the remote changes (e.g.
        hint: 'git pull ...') before pushing again.
        """
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .nonFastForward(_, let diverged) = o {
            XCTAssertFalse(diverged, "默认 historyDiverged 应为 false")
        } else {
            XCTFail("期望 nonFastForward，实际 \(o)")
        }
    }

    func testNonFastForwardWithHistoryDivergedFlag() {
        // 模拟 PushExecutor 在 caller 端检测出 historyDiverged 后传给 classify
        let stderr = "! [rejected] main -> main (non-fast-forward)"
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1, historyDiverged: true)
        if case .nonFastForward(_, let diverged) = o {
            XCTAssertTrue(diverged, "传入 true 应正确传递到 outcome")
        } else {
            XCTFail("期望 nonFastForward(diverged: true)，实际 \(o)")
        }
        XCTAssertTrue(o.isHistoryDiverged, "isHistoryDiverged convenience 应返回 true")
    }

    func testForceWithLeaseStaleIsNotDiverged() {
        // --force-with-lease 失败（远程被别人 push 过）= 普通 non-fast-forward，不脱钩
        let stderr = """
        ! [rejected]        main -> main (stale info)
        error: failed to push some refs
        hint: remote ref is at 'abc123' but expected 'def456'
        """
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .nonFastForward(_, let diverged) = o {
            XCTAssertFalse(diverged, "stale lease 是普通 non-FF，不是 history 脱钩")
        } else {
            XCTFail("期望 nonFastForward，实际 \(o)")
        }
    }

    // MARK: - Hook

    func testPrePushHookDetected() {
        let stderr = """
        Running pre-push hook...
        error: pre-push hook declined
        error: failed to push some refs to 'origin'
        """
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .hookRejected = o { /* ok */ } else { XCTFail("期望 hookRejected，实际 \(o)") }
    }

    // MARK: - Network

    func testDNSResolutionFailureDetected() {
        let stderr = "ssh: Could not resolve hostname github.com: nodename nor servname provided"
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .networkError = o { /* ok */ } else { XCTFail("期望 networkError，实际 \(o)") }
    }

    func testConnectionRefusedDetected() {
        let stderr = "fatal: unable to access 'https://github.com/x/y.git/': Failed to connect to github.com port 443"
        let o = PushExecutor.classify(result: result(stderr), commitCount: 1)
        if case .networkError = o { /* ok */ } else { XCTFail("期望 networkError，实际 \(o)") }
    }

    // MARK: - Unknown 兜底

    func testUnknownGoesToUnknown() {
        let stderr = "fatal: some bizarre new error nobody has seen before"
        let o = PushExecutor.classify(result: result(stderr, exit: 128), commitCount: 1)
        if case .unknown(_, let code) = o {
            XCTAssertEqual(code, 128)
        } else {
            XCTFail("期望 unknown，实际 \(o)")
        }
    }

    func testNilResultBecomesUnknown() {
        let o = PushExecutor.classify(result: nil, commitCount: 1)
        if case .unknown = o { /* ok */ } else { XCTFail("nil result 应该归类为 unknown") }
    }

    // MARK: - PushOutcome 自身的属性

    func testIsSuccessAccessor() {
        XCTAssertTrue(PushOutcome.success(pushedCount: 1).isSuccess)
        XCTAssertFalse(PushOutcome.authenticationFailed(stderr: "").isSuccess)
        XCTAssertFalse(PushOutcome.unknown(stderr: "", exitCode: 1).isSuccess)
    }

    func testStderrTruncation() {
        let huge = String(repeating: "x", count: 5000)
        let o = PushOutcome.unknown(stderr: huge, exitCode: 1)
        XCTAssertEqual(o.stderrTrimmed.count, 2000)
    }
}
