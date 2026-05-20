import Foundation

/// 「新版本已发车」推送信 —— Pilo 主动告诉用户「有新版本可下载」。
///
/// 跟 ReleaseLetter 区别：
///   - ReleaseLetter（bundle）：用户**已经升级到新版**后，看「这个版本带了什么」
///   - UpdateAvailableLetter（fetch）：用户**还在老版本**，告诉他「v0.5 出了，
///     这是下载链接」—— 引导动作
///
/// 持久化在 update-available.json（独立文件）。同时最多 1 封（最新已知可下载版本）；
/// 检测到更新的版本时覆盖；用户升级后该信箱被清空。
struct UpdateAvailableLetter: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    /// 新版本号，如 "0.5.0"
    let version: String
    /// 发布日期（来自 manifest 的 releaseDate）
    let releaseDate: Date
    /// Pilo 本机首次发现这个新版本的时间
    let detectedAt: Date
    /// 用户阅读的时间。nil = 未读
    var readAt: Date?

    let title: String
    let enTitle: String?
    let highlights: [String]
    let enHighlights: [String]?

    /// 用户点「下载新版本」按钮跳转的 URL（一般是 GitHub Release 页 / dmg 链接）
    let downloadURL: URL
    /// 可选：更详细 release notes 页（GitHub Release tag 页等）
    let releaseNotesURL: URL?

    init(
        id: UUID = UUID(),
        version: String,
        releaseDate: Date,
        detectedAt: Date = Date(),
        readAt: Date? = nil,
        title: String,
        enTitle: String? = nil,
        highlights: [String],
        enHighlights: [String]? = nil,
        downloadURL: URL,
        releaseNotesURL: URL? = nil
    ) {
        self.id = id
        self.version = version
        self.releaseDate = releaseDate
        self.detectedAt = detectedAt
        self.readAt = readAt
        self.title = title
        self.enTitle = enTitle
        self.highlights = highlights
        self.enHighlights = enHighlights
        self.downloadURL = downloadURL
        self.releaseNotesURL = releaseNotesURL
    }

    var isUnread: Bool { readAt == nil }
}

/// update-available.json 顶层容器。至多 1 封信。
struct UpdateAvailableArchive: Codable, Sendable {
    var version: Int
    /// nil = 当前已是最新 / 没检测到更新；非 nil = 有可下载新版本
    var current: UpdateAvailableLetter?

    static let currentVersion = 1
    static let empty = UpdateAvailableArchive(version: currentVersion, current: nil)
}

/// 服务器 manifest 顶层结构（Emma 维护的 updates.json）
struct UpdateManifest: Codable, Sendable {
    let latest: ManifestRelease
}

struct ManifestRelease: Codable, Sendable, Hashable {
    let version: String
    let releaseDate: Date
    let title: String
    let enTitle: String?
    let highlights: [String]
    let enHighlights: [String]?
    let downloadURL: URL
    let releaseNotesURL: URL?
    /// 可选 macOS 系统版本要求，如 "14.0"。低于这个版本的 mac 不推送
    let minimumSystemVersion: String?
}
