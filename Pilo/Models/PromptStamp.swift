import Foundation
import SwiftUI

/// 一张「Prompt 邮票」—— 用户收藏的可复用 prompt，跨 AI 工具通用。
///
/// 用户在任何 AI 工具里都能 paste 同一个 prompt：
///   - Cursor / Claude Code / Aider / Gemini chat 框里 ⌘V
///   - 任何 chat-style AI app
///
/// 设计哲学：Pilo 当 prompt 库的「中立第三方」——不绑定任何具体 AI。
///
/// Sidebar 底部只显示**钉住**的邮票（最多 5 张，按 lastUsedAt 倒序），其余在
/// archive sheet 里看全集。
struct PromptStamp: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    /// 短标题，sidebar / archive 行可见。建议 ≤ 16 字
    var title: String
    /// 完整 prompt 文本 —— click 邮票时复制到剪贴板的内容
    var body: String
    /// 装饰 emoji（单字符），居中显示在邮票圆里。建议 1 个 emoji
    var emoji: String
    /// 邮票底色（6 选 1）
    var tint: StampTint
    /// 是否钉在 sidebar 顶部 —— sidebar 只展示前 5 张钉住的邮票
    var pinned: Bool
    let createdAt: Date
    /// 上次 click 复制的时间 —— 用于 sidebar 排序
    var lastUsedAt: Date?
    /// 累计 click 次数 —— archive 里展示"用过 N 次"
    var useCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        emoji: String,
        tint: StampTint = .gold,
        pinned: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.emoji = emoji
        self.tint = tint
        self.pinned = pinned
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    /// 邮票底色 —— 6 个跟 Pilo 设计系统对齐的可选色
    enum StampTint: String, Codable, CaseIterable, Sendable {
        case blue       // 重构 / 结构类
        case gold       // 解释 / 文档类
        case rose       // debug / 修 bug 类
        case mint       // 测试 / 验证类
        case lavender   // 探索 / 研究类
        case neutral    // 通用

        var color: Color {
            switch self {
            case .blue:     return .piloBlue
            case .gold:     return .piloGoldDark
            case .rose:     return .roseDanger
            case .mint:     return .mintSafe
            case .lavender: return .lavenderInfo
            case .neutral:  return .inkSecondary
            }
        }

        /// 中文 label —— picker 用
        var labelZH: String {
            switch self {
            case .blue:     return "蓝"
            case .gold:     return "金"
            case .rose:     return "玫"
            case .mint:     return "绿"
            case .lavender: return "紫"
            case .neutral:  return "灰"
            }
        }
    }
}

/// 邮票本顶层容器
struct PromptStampArchive: Codable, Sendable {
    var version: Int
    var stamps: [PromptStamp]

    static let currentVersion = 1
    static let empty = PromptStampArchive(version: currentVersion, stamps: [])
}
