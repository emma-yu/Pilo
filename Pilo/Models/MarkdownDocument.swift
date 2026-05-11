import Foundation

/// 解析后的 Markdown 文档：一序列 Block。
/// 用 line-based parser 解析（见 `MarkdownRenderer`），不依赖第三方库。
struct MarkdownDocument: Sendable {

    /// SwiftUI 的 ForEach 用 enumerated.offset 作 id，所以 Block 本身不需要 Identifiable。
    enum Block: Sendable {
        case heading(level: Int, content: AttributedString, anchor: String)
        case paragraph(content: AttributedString)
        case codeBlock(language: String?, code: String)
        case bulletList(items: [AttributedString])
        case orderedList(items: [AttributedString])
        case quote(content: AttributedString)
        case horizontalRule
        /// 段落间空行——渲染时给一个 spacer 而不是 0 高度。
        case spacer
    }

    let blocks: [Block]
    /// 文件因为太长被截断或拒绝渲染。UI 会显示"用编辑器打开"卡片。
    let truncated: Bool
    let totalLines: Int
}
