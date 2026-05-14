import Foundation

/// 总局来信 —— 新欣明德设计工作室经由 Pilo 邮政总局投递的偶发信件。
/// 用途：年报 / 工作室通讯 / 姊妹作品引导（如 UVPeek）。
///
/// 跟 ReleaseLetter / DailyLetter 平行（不嵌套到一个 enum 里）—— 持久化分开存，
/// 互不污染、各自向后兼容；只在 InboxItem 层合并展示。
///
/// **频率上限**: ≤ 1 封 / 自然年（由 AppState.injectNewStudioLettersIfNeeded 强制把关）。
///
/// **红线**（CLAUDE.md 家规 + plan 文件「文案诚信红线」）:
///   - 信件正文 / 亮点 / CTA 都不能写最高级、不可验证社交证明、医疗暗示
///   - 年限流不可绕过；不可手动 force 投递
struct StudioLetter: Codable, Sendable, Identifiable, Hashable {
    /// 稳定字符串 id（不是 UUID）—— 跟 bundled JSON 里的 id 一一对应，做去重 key。
    /// 改名 / 重投同一封信时，新 id = 新条目。
    let id: String
    /// 信件「寄出」日期（authoring time，不是用户首次见到的时间）
    let sentDate: Date
    /// 用户本机首次见到这封信的时间（写入信箱时填）
    let deliveredAt: Date
    /// 用户阅读的时间。nil = 未读
    var readAt: Date?

    let title: String
    let highlights: [String]
    let bodyParagraphs: [String]
    /// 可选 CTA 按钮（如「去看看 UVPeek」），nil = 不显示按钮
    let cta: StudioLetterCTA?

    var isUnread: Bool { readAt == nil }
}

struct StudioLetterCTA: Codable, Sendable, Hashable {
    let label: String
    let url: URL
}

/// studio-letters.json 顶层容器
struct StudioLetterArchive: Codable, Sendable {
    var version: Int
    var letters: [StudioLetter]

    static let currentVersion = 1
    static let empty = StudioLetterArchive(version: currentVersion, letters: [])
}
