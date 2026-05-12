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

    init(hash: String, subject: String, date: Date, author: String, authorEmail: String? = nil) {
        self.hash = hash
        self.subject = subject
        self.date = date
        self.author = author
        self.authorEmail = authorEmail
    }
}
