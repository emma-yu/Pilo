import Foundation

/// 每日工作总结信件 —— Pilo 邮局每天 18:00 投递的"信"。
/// 替代之前的"主面板顶部 widget"：信件是事件、有仪式感、可翻阅。
struct DailyLetter: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    /// 信件覆盖的日期（用户本地 timezone 的当天）。同一天最多 1 封。
    let date: Date
    /// 实际投递时间（≈ 18:00 当天，或启动时补发的时间）
    let deliveredAt: Date
    /// 用户首次打开阅读的时间。nil = 未读
    var readAt: Date?

    /// 今天有活动（commit / push）的仓库摘要
    let repoSummaries: [RepoSummary]
    /// 今天有未提交改动但没今日 commit 的仓库（"桌上还有"）
    let draftRepos: [DraftSummary]

    /// 总 commit 数（累加 repoSummaries[].commits.count）
    let totalCommits: Int
    /// active repo count（commit + 草稿不重复计算）
    let activeRepoCount: Int
    /// 工作时段（仅 totalCommits > 0 时有）
    var workSpan: WorkSpan? = nil
    /// 收信人称呼（dynamic name；空 = fallback 到 "朋友"）
    var addressee: String? = nil
    /// 今日 AI 协作摘要 —— optional 向后兼容旧 letters.json
    var aiCompanions: [AICompanionSummary]? = nil

    struct RepoSummary: Codable, Sendable, Hashable {
        let repoName: String
        let repoPath: String
        let commitCount: Int          // 今天 commit 数
        let pushed: Bool              // 是否已 push（== aheadCount 0 启发）
        let remote: String?           // 推到哪
        /// 今天的 commits，前 5 个（subject + hash）
        let commits: [LetterCommit]
        /// 实际 commit 总数 - 5 = 省略数
        var moreCount: Int { max(0, commitCount - commits.count) }
        /// 今天累加 +/- 行数
        var linesAdded: Int = 0
        var linesRemoved: Int = 0
    }

    struct LetterCommit: Codable, Sendable, Hashable {
        let hash: String
        let subject: String
    }

    struct DraftSummary: Codable, Sendable, Hashable {
        let repoName: String
        let repoPath: String
        let uncommittedCount: Int
        /// 前 3 个未提交文件的相对路径
        var topFiles: [String] = []
    }

    /// 工作时段：今天第一个 commit → 最后一个 commit。
    /// 仅在 totalCommits > 0 时生成；可 nil。
    struct WorkSpan: Codable, Sendable, Hashable {
        let firstCommit: Date
        let lastCommit: Date

        /// 跨度小时数（lastCommit - firstCommit）
        var hours: Double {
            max(0, lastCommit.timeIntervalSince(firstCommit) / 3600)
        }
    }

    /// 没活动 → 没信件（caller 应判断 isWorthSending 决定要不要存）
    var isWorthSending: Bool {
        totalCommits > 0 || !draftRepos.isEmpty
    }

    var isUnread: Bool { readAt == nil }
}

/// 今日"邮局合作社" —— 跨 AI 工具的活跃度摘要。
/// 数据来自 `AICompanionDetector` 扫各工具数据目录的文件 mtime（不读内容）。
struct AICompanionSummary: Codable, Sendable, Hashable {
    let tool: AITool
    /// 今天检测到的活动单位数。Per-tool 定义：
    ///   - Claude Code: 今天被改的 `.jsonl` conversation 文件数
    ///   - Cursor / Windsurf: 今天被改的 workspace 子目录数
    ///   - Codex / Gemini: 今天被改的文件数
    ///   - Aider: 今天有 `.aider.chat.history.md` mtime 的 repo 数
    let activityCount: Int
}

/// 信件箱顶层容器
struct LetterArchive: Codable, Sendable {
    var version: Int
    var letters: [DailyLetter]

    static let currentVersion = 1
    static let empty = LetterArchive(version: currentVersion, letters: [])

    /// 是否有某日的信
    func letter(forDate date: Date) -> DailyLetter? {
        let cal = Calendar.current
        return letters.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    /// 是否有未读信件
    var hasUnread: Bool { letters.contains(where: \.isUnread) }
    var unreadCount: Int { letters.filter(\.isUnread).count }
}
