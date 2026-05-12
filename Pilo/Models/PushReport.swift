import Foundation

/// 单次 push 的结果分类。stderr 的关键短语决定走哪条分支。
enum PushOutcome: Sendable, Hashable {
    case success(pushedCount: Int)
    case authenticationFailed(stderr: String)
    /// non-fast-forward 失败。`historyDiverged` 区分两种 sub-case：
    ///   - false: 远程有别人 push 的新 commit，正常 pull --rebase 即可
    ///   - true:  本地 history 重写过（filter-repo / rebase / amend），跟远程**无共同祖先**。
    ///            **pull 会污染本地** —— 应该用 force-with-lease 覆盖远程。
    case nonFastForward(stderr: String, historyDiverged: Bool)
    case hookRejected(stderr: String)
    case networkError(stderr: String)
    case noUpstreamConfigured(stderr: String)
    case unknown(stderr: String, exitCode: Int32)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// 是否是"历史脱钩"情况 —— UI 据此显示「覆盖远程历史」按钮而非 pull 提示。
    var isHistoryDiverged: Bool {
        if case .nonFastForward(_, let diverged) = self { return diverged }
        return false
    }

    var stderrTrimmed: String {
        switch self {
        case .success: ""
        case .authenticationFailed(let s),
             .nonFastForward(let s, _),
             .hookRejected(let s),
             .networkError(let s),
             .noUpstreamConfigured(let s):
            String(s.prefix(2000))
        case .unknown(let s, _):
            String(s.prefix(2000))
        }
    }
}

/// 一次 push 操作的完整记录。
struct PushReport: Sendable, Hashable, Identifiable {
    let id: UUID
    let repoId: UUID
    let repoName: String
    let remote: String
    let branch: String
    let commitCount: Int
    let outcome: PushOutcome
    let timestamp: Date

    init(
        repoId: UUID,
        repoName: String,
        remote: String,
        branch: String,
        commitCount: Int,
        outcome: PushOutcome
    ) {
        self.id = UUID()
        self.repoId = repoId
        self.repoName = repoName
        self.remote = remote
        self.branch = branch
        self.commitCount = commitCount
        self.outcome = outcome
        self.timestamp = Date()
    }
}
