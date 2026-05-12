import Foundation

/// S2 跨 Repo 工作日报：跨所有 repo 聚合"今天"的活动数据。
/// 设计原则：
///   - 跨 repo 并发拉数据（TaskGroup），30 个 repos 总耗时 ≤ 1s
///   - 失败 fallback 空 row（不阻塞 UI）
///   - 不持久化，每次 compute 重新拉
actor DailyDigestService {

    let gitClient: GitClient

    init(gitClient: GitClient) {
        self.gitClient = gitClient
    }

    /// 跨 repos 聚合今天活动。caller 应在 detached Task 跑（避免占 MainActor）。
    func compute(repos: [Repository]) async -> DailyDigest {
        let today = Self.startOfToday()
        let visible = repos.filter { !$0.isHidden }

        // 并发收集每个 repo 的"今天 commits"
        let rows = await withTaskGroup(of: RepoActivity?.self) { group in
            for repo in visible {
                let gc = gitClient
                group.addTask {
                    await Self.collectActivity(repo: repo, since: today, gitClient: gc)
                }
            }
            var collected: [RepoActivity] = []
            for await item in group {
                if let item { collected.append(item) }
            }
            return collected
        }

        // 分桶：pushed today / commits but not pushed today / visited only
        var pushed: [DailyDigest.DigestRow] = []
        var modifiedNotPushed: [DailyDigest.DigestRow] = []
        var visited: [DailyDigest.DigestRow] = []

        for r in rows {
            let row = DailyDigest.DigestRow(
                repoId: r.repoId,
                repoName: r.repoName,
                repoPath: r.repoPath,
                commitsToday: r.commitsToday,
                lastActivityToday: r.lastActivity
            )
            if r.commitsToday > 0 {
                if r.pushedToday {
                    pushed.append(row)
                } else {
                    modifiedNotPushed.append(row)
                }
            } else if r.visitedToday {
                visited.append(row)
            }
        }

        // 按活动时间倒序
        pushed.sort { $0.lastActivityToday > $1.lastActivityToday }
        modifiedNotPushed.sort { $0.lastActivityToday > $1.lastActivityToday }
        visited.sort { $0.lastActivityToday > $1.lastActivityToday }

        return DailyDigest(
            date: today,
            pushedRepos: pushed,
            modifiedNotPushed: modifiedNotPushed,
            visitedOnly: visited
        )
    }

    // MARK: - 内部

    private struct RepoActivity: Sendable {
        let repoId: UUID
        let repoName: String
        let repoPath: String
        let commitsToday: Int
        let lastActivity: Date
        /// 今天的 commits 是不是已经 push 完了（用 aheadCount 估算：== 0 表示已 push）
        let pushedToday: Bool
        /// 今天用户在 Pilo 里点开过（lastViewedDate >= today）
        let visitedToday: Bool
    }

    private static func collectActivity(
        repo: Repository,
        since: Date,
        gitClient: GitClient
    ) async -> RepoActivity? {
        // 拉今天的 commits
        let url = URL(fileURLWithPath: repo.path)
        let commits = await gitClient.commitsSince(repo: url, since: since)
        let commitsCount = commits.count
        let lastCommitDate = commits.first?.date

        // visitedToday: lastViewedDate >= today's start
        let visited = (repo.lastViewedDate ?? .distantPast) >= since

        // 没今天的 commit 也没今天访问过 → 不算 active，drop
        if commitsCount == 0 && !visited {
            return nil
        }

        // 最近活动时间 = max(lastCommit today, lastViewedDate today)
        var lastActivity = lastCommitDate ?? .distantPast
        if let v = repo.lastViewedDate, v > lastActivity { lastActivity = v }

        // pushedToday 启发式：今天 commit 数 > 0 且 aheadCount == 0
        // = "今天产生的 commit 应该都 push 完了"
        let pushedToday = commitsCount > 0 && repo.aheadCount == 0

        return RepoActivity(
            repoId: repo.id,
            repoName: repo.name,
            repoPath: repo.path,
            commitsToday: commitsCount,
            lastActivity: lastActivity,
            pushedToday: pushedToday,
            visitedToday: visited
        )
    }

    /// 用户本地 timezone 今天的 0:00
    static func startOfToday(now: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: now)
    }
}
