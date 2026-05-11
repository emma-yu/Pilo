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
        falsePositiveMarks: [FalsePositiveMark] = []
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
    }

    // Codable 向后兼容：旧 state.json 没有 falsePositiveMarks 字段时默认为空。
    // 不写自定义 init(from:) 的话，自动合成的 decoder 会因为字段缺失而 throw。
    private enum CodingKeys: String, CodingKey {
        case id, pathHash, path, name, currentBranch, aheadCount, behindCount,
             uncommittedCount, lastCommitDate, lastFetchDate, lastFetchSuccess,
             remotes, defaultPushRemote, firstCommitHash, isHidden, customTags,
             lastScanDate, skipFetch, skipMainBranchWarning, falsePositiveMarks
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
        // 关键：新字段缺失时默认空数组
        self.falsePositiveMarks = try c.decodeIfPresent([FalsePositiveMark].self, forKey: .falsePositiveMarks) ?? []
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
