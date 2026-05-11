import Foundation

/// 单次 push 的结果分类。stderr 的关键短语决定走哪条分支。
enum PushOutcome: Sendable, Hashable {
    case success(pushedCount: Int)
    case authenticationFailed(stderr: String)
    case nonFastForward(stderr: String)
    case hookRejected(stderr: String)
    case networkError(stderr: String)
    case noUpstreamConfigured(stderr: String)
    case unknown(stderr: String, exitCode: Int32)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var stderrTrimmed: String {
        switch self {
        case .success: ""
        case .authenticationFailed(let s),
             .nonFastForward(let s),
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
