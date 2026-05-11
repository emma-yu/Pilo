import Foundation

/// 负责执行 git push、把 stderr 翻译成 `PushOutcome`、多仓库顺序推送。
///
/// 关键设计：
///   - 顺序而非并行（PRD §4.3）：500ms 间隔避免触发 GitHub 的 rate limit
///     和让用户认知跟上 UI 滚动
///   - 凭证交互：GIT_TERMINAL_PROMPT=0 已经在 GitClient 强制；这意味着 push
///     不会卡在交互式 prompt 上——它会立刻失败，然后我们识别为 `.authenticationFailed`
///     并提示用户去终端配置 credential helper
///   - 不在这里做安全扫描（Phase 6）；只做"按按钮 → push → 分类结果"
actor PushExecutor {

    let gitClient: GitClient

    init(gitClient: GitClient) {
        self.gitClient = gitClient
    }

    /// 单仓库 push。
    func push(
        repoURL: URL,
        repoId: UUID,
        repoName: String,
        remote: String,
        branch: String,
        commitCount: Int,
        setUpstream: Bool
    ) async -> PushReport {
        let result = await gitClient.push(repo: repoURL, remote: remote, branch: branch, setUpstream: setUpstream)
        let outcome = Self.classify(result: result, commitCount: commitCount)
        return PushReport(
            repoId: repoId,
            repoName: repoName,
            remote: remote,
            branch: branch,
            commitCount: commitCount,
            outcome: outcome
        )
    }

    // MARK: - stderr → PushOutcome 分类

    static func classify(result: GitClient.ProcessResult?, commitCount: Int) -> PushOutcome {
        guard let result else {
            return .unknown(stderr: "git command unavailable", exitCode: -1)
        }
        if result.ok {
            return .success(pushedCount: commitCount)
        }

        let stderr = result.stderr
        let lower = stderr.lowercased()

        // Network / DNS issues
        if Self.matchesAny(lower, of: [
            "could not resolve host",
            "network is unreachable",
            "operation timed out",
            "connection refused",
            "ssl_connect",
            "failed to connect to",
        ]) {
            return .networkError(stderr: stderr)
        }

        // No upstream configured
        if Self.matchesAny(lower, of: [
            "the current branch",
            "has no upstream branch",
            "src refspec",
            "no upstream configured",
        ]) && lower.contains("upstream") {
            return .noUpstreamConfigured(stderr: stderr)
        }

        // Pre-push hook
        if Self.matchesAny(lower, of: [
            "pre-push hook",
            "hook declined",
            "remote hook",
        ]) {
            return .hookRejected(stderr: stderr)
        }

        // Non-fast-forward
        if Self.matchesAny(lower, of: [
            "non-fast-forward",
            "tip of your current branch is behind",
            "updates were rejected",
            "fetch first",
        ]) {
            return .nonFastForward(stderr: stderr)
        }

        // Authentication
        if Self.matchesAny(lower, of: [
            "authentication failed",
            "could not read username",
            "permission denied (publickey)",
            "support for password authentication was removed",
            "invalid username or token",
            "terminal prompts disabled",
            "fatal: could not read password",
        ]) {
            return .authenticationFailed(stderr: stderr)
        }

        return .unknown(stderr: stderr, exitCode: result.exitCode)
    }

    private static func matchesAny(_ haystack: String, of needles: [String]) -> Bool {
        for n in needles where haystack.contains(n) {
            return true
        }
        return false
    }
}
