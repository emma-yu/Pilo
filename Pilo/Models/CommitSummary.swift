import Foundation

/// 单条 commit 的展示摘要，用于 PushConfirmDialog。
/// 从 `git log <range> --format='%h%x00%s%x00%ct%x00%an'` 解析。
struct CommitSummary: Identifiable, Hashable, Sendable {
    var id: String { hash }
    let hash: String          // 7-char short hash
    let subject: String       // 第一行 commit message
    let date: Date
    let author: String
}
