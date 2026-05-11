import Foundation
import CryptoKit

struct Repository: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let pathHash: String          // SHA256(path) — 匹配主键，path 可变时保留元数据
    var path: String              // 绝对路径
    var name: String              // 显示名（默认 = 目录名）

    // git 状态
    var currentBranch: String?
    var aheadCount: Int
    var behindCount: Int
    var uncommittedCount: Int
    var lastCommitDate: Date?
    var lastFetchDate: Date?
    var lastFetchSuccess: Bool

    // remote
    var remotes: [GitRemote]
    var defaultPushRemote: String  // 通常 "origin"

    // 元数据
    var firstCommitHash: String?
    var isHidden: Bool
    var customTags: [String]
    var lastScanDate: Date

    // 每仓库配置（PRD §6 v1.1）
    var skipFetch: Bool
    var skipMainBranchWarning: Bool

    init(
        id: UUID = UUID(),
        path: String,
        name: String? = nil,
        currentBranch: String? = nil,
        aheadCount: Int = 0,
        behindCount: Int = 0,
        uncommittedCount: Int = 0,
        lastCommitDate: Date? = nil,
        lastFetchDate: Date? = nil,
        lastFetchSuccess: Bool = false,
        remotes: [GitRemote] = [],
        defaultPushRemote: String = "origin",
        firstCommitHash: String? = nil,
        isHidden: Bool = false,
        customTags: [String] = [],
        lastScanDate: Date = Date(),
        skipFetch: Bool = false,
        skipMainBranchWarning: Bool = false
    ) {
        self.id = id
        self.pathHash = Self.hash(path: path)
        self.path = path
        self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
        self.currentBranch = currentBranch
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.uncommittedCount = uncommittedCount
        self.lastCommitDate = lastCommitDate
        self.lastFetchDate = lastFetchDate
        self.lastFetchSuccess = lastFetchSuccess
        self.remotes = remotes
        self.defaultPushRemote = defaultPushRemote
        self.firstCommitHash = firstCommitHash
        self.isHidden = isHidden
        self.customTags = customTags
        self.lastScanDate = lastScanDate
        self.skipFetch = skipFetch
        self.skipMainBranchWarning = skipMainBranchWarning
    }

    static func hash(path: String) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 显示派生属性

    /// 用户感兴趣的"需要做点什么"
    var hasWork: Bool {
        aheadCount > 0 || uncommittedCount > 0
    }

    var statusSummary: StatusKind {
        if uncommittedCount > 0 { return .uncommitted }
        if aheadCount > 0 { return .ahead }
        if behindCount > 0 { return .behind }
        return .synced
    }

    enum StatusKind: Sendable {
        case synced, ahead, behind, uncommitted
    }
}

/// 顶层持久化容器，预留 schema version 用于未来迁移
struct RepositoryStore: Codable, Sendable {
    var version: Int
    var repositories: [Repository]

    static let currentVersion = 1
    static let empty = RepositoryStore(version: currentVersion, repositories: [])
}
