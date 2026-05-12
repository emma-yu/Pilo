import Foundation

/// S2 跨 Repo 工作日报：聚合"今天"在所有 watch dirs 内 git 仓库的活动。
/// **纯派生数据**，不持久化 —— 重启时由 DailyDigestService 重算。
struct DailyDigest: Sendable, Equatable {
    /// 该 digest 对应的"今天"日期（用户本地 timezone 的 0:00 至现在）
    let date: Date
    /// 今天已经 push 过的 repos（commit 数 + 最近活动时间）
    let pushedRepos: [DigestRow]
    /// 今天有 commit 但还没 push（待寄出）
    let modifiedNotPushed: [DigestRow]
    /// 今天用户在 Pilo 里点开过但没改动（lastViewedDate = today）
    let visitedOnly: [DigestRow]

    struct DigestRow: Sendable, Hashable, Identifiable {
        var id: UUID { repoId }
        let repoId: UUID
        let repoName: String
        let repoPath: String
        /// 今天产生的 commit 数（不含 push 前的）
        let commitsToday: Int
        /// 今天最后活动时间（最新 commit 或 lastViewedDate）
        let lastActivityToday: Date
    }

    var isEmpty: Bool {
        pushedRepos.isEmpty && modifiedNotPushed.isEmpty && visitedOnly.isEmpty
    }

    var totalActiveCount: Int {
        pushedRepos.count + modifiedNotPushed.count + visitedOnly.count
    }
}
