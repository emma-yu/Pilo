import Foundation

/// 每日信件 composer：把今天的跨 repo 活动**详细**聚合成一封 DailyLetter。
///
/// 跟之前的 DailyDigestService 区别：
///   - 不止 count，列具体 commit subjects（前 5 个）
///   - 区分 pushed / drafting / uncommitted
///   - 不包括"今天看过但没改"（用户说不关心这个 noise）
actor LetterComposer {

    let gitClient: GitClient

    init(gitClient: GitClient) {
        self.gitClient = gitClient
    }

    /// 为"今天"compose 一封信。caller 应判断 letter.isWorthSending 决定要不要存。
    /// - Parameters:
    ///   - repos: 全部 watch repos
    ///   - date: 哪一天的信（默认今天）—— 用于补发
    func compose(repos: [Repository], date: Date = Date()) async -> DailyLetter {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let visible = repos.filter { !$0.isHidden }

        // 并发拉每个 repo 的"今天 commits"
        let activities = await withTaskGroup(of: RepoActivity?.self) { group in
            for repo in visible {
                let gc = gitClient
                group.addTask {
                    await Self.collectActivity(
                        repo: repo,
                        startOfDay: startOfDay,
                        endOfDay: endOfDay,
                        gitClient: gc
                    )
                }
            }
            var collected: [RepoActivity] = []
            for await item in group {
                if let item { collected.append(item) }
            }
            return collected
        }

        // 分桶：有 commit 的 → RepoSummary；没 commit 但有未提交的 → DraftSummary
        var summaries: [DailyLetter.RepoSummary] = []
        var drafts: [DailyLetter.DraftSummary] = []

        for a in activities {
            if a.todayCommits.isEmpty {
                if a.uncommittedCount > 0 {
                    drafts.append(.init(
                        repoName: a.repoName,
                        repoPath: a.repoPath,
                        uncommittedCount: a.uncommittedCount
                    ))
                }
                continue
            }
            // 取前 5 个 commits 写信
            let topCommits = a.todayCommits.prefix(5).map {
                DailyLetter.LetterCommit(hash: $0.hash, subject: $0.subject)
            }
            summaries.append(.init(
                repoName: a.repoName,
                repoPath: a.repoPath,
                commitCount: a.todayCommits.count,
                pushed: a.pushedToday,
                remote: a.defaultRemote,
                commits: Array(topCommits)
            ))
        }

        // 按 commit 数倒序（产出最多的排前）
        summaries.sort { $0.commitCount > $1.commitCount }
        drafts.sort { $0.uncommittedCount > $1.uncommittedCount }

        let totalCommits = summaries.reduce(0) { $0 + $1.commitCount }
        let activeCount = summaries.count + drafts.count

        return DailyLetter(
            id: UUID(),
            date: startOfDay,
            deliveredAt: Date(),
            readAt: nil,
            repoSummaries: summaries,
            draftRepos: drafts,
            totalCommits: totalCommits,
            activeRepoCount: activeCount
        )
    }

    // MARK: - 内部

    private struct RepoActivity: Sendable {
        let repoId: UUID
        let repoName: String
        let repoPath: String
        let todayCommits: [CommitSummary]
        let pushedToday: Bool
        let uncommittedCount: Int
        let defaultRemote: String?
    }

    private static func collectActivity(
        repo: Repository,
        startOfDay: Date,
        endOfDay: Date,
        gitClient: GitClient
    ) async -> RepoActivity? {
        let url = URL(fileURLWithPath: repo.path)
        // 拉今天 commits
        let all = await gitClient.commitsSince(repo: url, since: startOfDay)
        // 过滤到今天范围内（commitsSince 是 >= since，但用户期望严格 today）
        let todayCommits = all.filter { $0.date < endOfDay }

        // pushedToday 启发：commits > 0 && aheadCount == 0
        let pushedToday = !todayCommits.isEmpty && repo.aheadCount == 0

        return RepoActivity(
            repoId: repo.id,
            repoName: repo.name,
            repoPath: repo.path,
            todayCommits: todayCommits,
            pushedToday: pushedToday,
            uncommittedCount: repo.uncommittedCount,
            defaultRemote: repo.defaultPushRemote
        )
    }
}
