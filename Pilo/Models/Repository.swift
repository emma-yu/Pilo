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

    // Phase 6 加入：误报标记（per-repo，跟随仓库元数据迁移；老 state.json 没这个字段时默认空数组）
    var falsePositiveMarks: [FalsePositiveMark]

    // === Phase B (Project Inventory) ===

    /// 用户手动贴的"投递箱"标签。scan 不会覆盖。
    var category: RepoCategory

    /// 仓库根有无 README.* 文件（每次 scan 时刷新）。
    var hasReadme: Bool

    /// 仓库根有无 tests / __tests__ / XxxTests 目录或测试约定文件（每次 scan 时刷新）。
    var hasTests: Bool

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
        skipMainBranchWarning: Bool = false,
        falsePositiveMarks: [FalsePositiveMark] = [],
        category: RepoCategory = .unset,
        hasReadme: Bool = false,
        hasTests: Bool = false
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
        self.falsePositiveMarks = falsePositiveMarks
        self.category = category
        self.hasReadme = hasReadme
        self.hasTests = hasTests
    }

    // Codable 向后兼容：旧 state.json 没有新字段时使用默认值。
    private enum CodingKeys: String, CodingKey {
        case id, pathHash, path, name, currentBranch, aheadCount, behindCount,
             uncommittedCount, lastCommitDate, lastFetchDate, lastFetchSuccess,
             remotes, defaultPushRemote, firstCommitHash, isHidden, customTags,
             lastScanDate, skipFetch, skipMainBranchWarning, falsePositiveMarks,
             category, hasReadme, hasTests
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.pathHash = try c.decode(String.self, forKey: .pathHash)
        self.path = try c.decode(String.self, forKey: .path)
        self.name = try c.decode(String.self, forKey: .name)
        self.currentBranch = try c.decodeIfPresent(String.self, forKey: .currentBranch)
        self.aheadCount = try c.decode(Int.self, forKey: .aheadCount)
        self.behindCount = try c.decode(Int.self, forKey: .behindCount)
        self.uncommittedCount = try c.decode(Int.self, forKey: .uncommittedCount)
        self.lastCommitDate = try c.decodeIfPresent(Date.self, forKey: .lastCommitDate)
        self.lastFetchDate = try c.decodeIfPresent(Date.self, forKey: .lastFetchDate)
        self.lastFetchSuccess = try c.decodeIfPresent(Bool.self, forKey: .lastFetchSuccess) ?? false
        self.remotes = try c.decodeIfPresent([GitRemote].self, forKey: .remotes) ?? []
        self.defaultPushRemote = try c.decodeIfPresent(String.self, forKey: .defaultPushRemote) ?? "origin"
        self.firstCommitHash = try c.decodeIfPresent(String.self, forKey: .firstCommitHash)
        self.isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.customTags = try c.decodeIfPresent([String].self, forKey: .customTags) ?? []
        self.lastScanDate = try c.decodeIfPresent(Date.self, forKey: .lastScanDate) ?? Date()
        self.skipFetch = try c.decodeIfPresent(Bool.self, forKey: .skipFetch) ?? false
        self.skipMainBranchWarning = try c.decodeIfPresent(Bool.self, forKey: .skipMainBranchWarning) ?? false
        self.falsePositiveMarks = try c.decodeIfPresent([FalsePositiveMark].self, forKey: .falsePositiveMarks) ?? []
        // Phase B 新字段：旧 state.json 没有 → 默认值
        self.category = try c.decodeIfPresent(RepoCategory.self, forKey: .category) ?? .unset
        self.hasReadme = try c.decodeIfPresent(Bool.self, forKey: .hasReadme) ?? false
        self.hasTests = try c.decodeIfPresent(Bool.self, forKey: .hasTests) ?? false
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

    // MARK: - Phase B (Project Inventory) 派生属性

    /// 仓库的"健康 mood"。纯由 lastCommitDate 派生，不持久化。
    /// nil（新建未 commit）→ active（默认显眼，鼓励用户开始）。
    var mood: RepoMood {
        guard let last = lastCommitDate else { return .active }
        let days = Date().timeIntervalSince(last) / 86400
        if days < 7 { return .active }
        if days < 30 { return .idle }
        if days < 90 { return .dying }
        return .abandoned
    }

    /// 距最后一次 commit 的天数。nil = 没有 commit 历史。
    var daysSinceLastCommit: Int? {
        guard let last = lastCommitDate else { return nil }
        return max(0, Int(Date().timeIntervalSince(last) / 86400))
    }
}

/// 顶层持久化容器，预留 schema version 用于未来迁移
struct RepositoryStore: Codable, Sendable {
    var version: Int
    var repositories: [Repository]

    static let currentVersion = 1
    static let empty = RepositoryStore(version: currentVersion, repositories: [])
}
