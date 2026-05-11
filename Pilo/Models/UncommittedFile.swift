import Foundation

/// Resume Work 卡片用：未提交文件的轻量信息。
/// 由 `GitClient.uncommittedFiles` 解析 `git status --porcelain` 得到。
struct UncommittedFile: Hashable, Sendable, Identifiable {
    enum Status: String, Sendable {
        case modified      // M
        case added         // A
        case deleted       // D
        case renamed       // R
        case untracked     // ??
        case conflicted    // U
        case copied        // C
        case other
    }

    let status: Status
    let path: String

    var id: String { "\(status.rawValue):\(path)" }
}
