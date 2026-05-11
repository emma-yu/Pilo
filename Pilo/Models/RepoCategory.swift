import Foundation

/// Project Inventory（Phase B）：用户给每个仓库贴的"投递箱"标签。
/// 用户手动设置，scan **不**覆盖；持久化在 state.json。
///
/// 邮局美学：work / personal / experiment 像信件上的分拣戳，
/// unset 表示"还没贴邮票"。
enum RepoCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case unset
    case work
    case personal
    case experiment

    /// UI 展示顺序：work → personal → experiment → unset（兜底）
    static var orderedDisplay: [RepoCategory] {
        [.work, .personal, .experiment, .unset]
    }
}
