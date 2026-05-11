import Foundation

/// Project Inventory（Phase B）：仓库的"健康 mood"，由 lastCommitDate 派生。
/// **不持久化** —— 永远 computed，避免因为缓存陈旧给用户错误的"复活"印象。
///
/// 边界：
///   - active: 0-7 天前最后一次 commit（或 lastCommitDate == nil，视为新生）
///   - idle:   7-30 天
///   - dying:  30-90 天
///   - abandoned: 90+ 天
enum RepoMood: String, Codable, Sendable, CaseIterable {
    case active
    case idle
    case dying
    case abandoned
}
