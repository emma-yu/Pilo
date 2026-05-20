import Foundation

/// 版本发布通告信 —— 用户拿到新版 Pilo 时，首次启动自动投递到信箱的一封"邮局通告"。
///
/// 跟 DailyLetter 平行（不嵌套到一个 enum 里）—— 持久化分两个文件，
/// 互不污染、各自向后兼容；只在 InboxView 层合并展示。
///
/// 不需要联网：release-notes.json 跟 app binary 一起 bundle，
/// 启动时跟 `UserDefaults.lastSeenReleaseVersion` 比较，新出现的版本生成一封信。
struct ReleaseLetter: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    /// 语义版本号字符串，如 "0.4.0"
    let version: String
    /// 这个版本发布的日期（authoring time，不是用户看到的时间）
    let releaseDate: Date
    /// 用户本机首次见到这封信的时间（写入信箱时填）
    let deliveredAt: Date
    /// 用户阅读的时间。nil = 未读
    var readAt: Date?

    let title: String
    let enTitle: String?
    /// 短 bullet 高亮（3-6 条最舒适）
    let highlights: [String]
    let enHighlights: [String]?
    /// 长段落（可选）—— 给愿意细读的人扩写细节
    let bodyParagraphs: [String]
    let enBodyParagraphs: [String]?

    init(
        id: UUID = UUID(),
        version: String,
        releaseDate: Date,
        deliveredAt: Date = Date(),
        readAt: Date? = nil,
        title: String,
        enTitle: String? = nil,
        highlights: [String],
        enHighlights: [String]? = nil,
        bodyParagraphs: [String] = [],
        enBodyParagraphs: [String]? = nil
    ) {
        self.id = id
        self.version = version
        self.releaseDate = releaseDate
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.title = title
        self.enTitle = enTitle
        self.highlights = highlights
        self.enHighlights = enHighlights
        self.bodyParagraphs = bodyParagraphs
        self.enBodyParagraphs = enBodyParagraphs
    }

    var isUnread: Bool { readAt == nil }
}

/// 信箱里的统一项（**仅 UI 层用**，不持久化）—— LetterArchiveView 把
/// DailyLetter / ReleaseLetter / UpdateAvailableLetter 合到一个数组排序。
enum InboxItem: Identifiable, Hashable, Sendable {
    case daily(DailyLetter)
    case release(ReleaseLetter)
    /// 总局来信 —— 工作室年报 / 姊妹作品引导
    case studio(StudioLetter)
    /// 「新版本已发车」推送信 —— 总排在信箱最顶（最重要的引导）
    case updateAvailable(UpdateAvailableLetter)

    var id: String {
        switch self {
        case .daily(let l):           return "d-\(l.id.uuidString)"
        case .release(let l):         return "r-\(l.id.uuidString)"
        case .studio(let l):          return "s-\(l.id)"
        case .updateAvailable(let l): return "u-\(l.id.uuidString)"
        }
    }

    /// 排序键 —— release 用 releaseDate，daily 用 date，studio 用 sentDate，update 用 detectedAt
    var sortDate: Date {
        switch self {
        case .daily(let l):           return l.date
        case .release(let l):         return l.releaseDate
        case .studio(let l):          return l.sentDate
        case .updateAvailable(let l): return l.detectedAt
        }
    }

    var isUnread: Bool {
        switch self {
        case .daily(let l):           return l.isUnread
        case .release(let l):         return l.isUnread
        case .studio(let l):          return l.isUnread
        case .updateAvailable(let l): return l.isUnread
        }
    }
}

/// release-letters.json 顶层容器
struct ReleaseLetterArchive: Codable, Sendable {
    var version: Int
    var letters: [ReleaseLetter]

    static let currentVersion = 1
    static let empty = ReleaseLetterArchive(version: currentVersion, letters: [])
}

// MARK: - Semver 比较（本地用，避免引入第三方 lib）

enum Semver {
    /// 比较 "0.4.0" 和 "0.3.2" 这种字符串。空 / 非数字段当 0。
    /// "1.10.0" > "1.9.0"（按数字段比，不是 lexicographic 字符串）
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(aParts.count, bParts.count)
        for i in 0..<n {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av < bv { return .orderedAscending }
            if av > bv { return .orderedDescending }
        }
        return .orderedSame
    }
}
