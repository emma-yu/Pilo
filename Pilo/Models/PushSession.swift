import Foundation

/// PushConfirmDialog 在 sheet 中跨多个阶段共享的状态。
///
/// 三个阶段：
///   - `.preflight(...)`：用户已经打开 sheet，看到要推什么；可以取消或开推
///   - `.running(...)`：git push 正在跑
///   - `.completed(report)`：成功 / 失败展示，等用户关闭 sheet
struct PushSession: Identifiable, Sendable {
    let id: UUID
    var state: State

    struct Preflight: Sendable, Hashable {
        let repoId: UUID
        let repoPath: String
        let repoName: String
        let remote: String
        let branch: String
        let willSetUpstream: Bool
        let commits: [CommitSummary]
    }

    struct Running: Sendable, Hashable {
        let remote: String
    }

    enum State: Sendable {
        case preflight(Preflight)
        case running(Running)
        case completed(PushReport)
    }

    init(preflight: Preflight) {
        self.id = UUID()
        self.state = .preflight(preflight)
    }
}
