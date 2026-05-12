import Foundation

/// 单条 commit 的展示摘要，用于 PushConfirmDialog。
/// 从 `git log <range> --format='%h%x00%s%x00%ct%x00%an%x00%ae'` 解析。
struct CommitSummary: Identifiable, Hashable, Sendable {
    var id: String { hash }
    let hash: String          // 7-char short hash
    let subject: String       // 第一行 commit message
    let date: Date
    let author: String        // author name (%an)
    /// author email (%ae)。S3 Identity Sentinel 用来做身份核对。
    /// 老调用方不传时 nil，identity check 会 skip 这 commit
    var authorEmail: String?

    /// S1 AI Push Guard: 启发式判断这个 commit 看起来像不像 AI 写的。
    /// 默认 .unknown；填充时机：RepoScanner / GitClient 拉 commits 后跑 detector。
    var aiLikelihood: AILikelihood = .unknown

    init(hash: String, subject: String, date: Date, author: String,
         authorEmail: String? = nil, aiLikelihood: AILikelihood = .unknown) {
        self.hash = hash
        self.subject = subject
        self.date = date
        self.author = author
        self.authorEmail = authorEmail
        self.aiLikelihood = aiLikelihood
    }
}

/// S1 启发式判断 commit 是不是 AI 写的。Indicative not authoritative —— UI 措辞用"看起来"。
enum AILikelihood: String, Sendable, Hashable {
    case unknown       // 无信号
    case maybeAI       // 1 个信号命中
    case likelyAI      // ≥2 个信号命中
}
