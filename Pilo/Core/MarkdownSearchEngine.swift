import Foundation

/// 单文档 in-doc 全文搜索（plain string, case-insensitive）。
///
/// 设计原则：
///   - **纯函数**：无副作用，方便测试 + view 调用
///   - **同步**：5000 行上限由 renderer 保证，毫秒级
///   - **跳过 codeBlock / horizontalRule / spacer**：搜文本不搜代码 (v1)
///   - **不存 range/index**：只返回 (blockIndex, occurrenceInBlock)
///     —— BlockView 自己 re-walk own AttributedString 找 ranges 加高亮
///     这样跨 caller / re-render 不会因 Range 失效崩
enum MarkdownSearchEngine {

    /// 全部命中 —— 按文档顺序，跨 block，多个命中同 block 各一个 hit
    struct Hit: Hashable, Sendable {
        let blockIndex: Int
        /// 该 block 内第几次出现（0-based）—— BlockView 用来对齐"当前 hit"高亮
        let occurrenceInBlock: Int
    }

    /// 主入口。空 query / 空 doc → 空数组。
    static func find(in doc: MarkdownDocument, query: String) -> [Hit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let needle = q.lowercased()

        var hits: [Hit] = []
        for (i, block) in doc.blocks.enumerated() {
            guard let haystack = plainText(of: block)?.lowercased() else { continue }
            var cursor = haystack.startIndex
            var occurrence = 0
            while cursor < haystack.endIndex,
                  let found = haystack.range(of: needle, range: cursor..<haystack.endIndex) {
                hits.append(Hit(blockIndex: i, occurrenceInBlock: occurrence))
                occurrence += 1
                cursor = found.upperBound
            }
        }
        return hits
    }

    /// 把一个 block 解出可搜索的 plain text。不可搜的 block → nil。
    /// codeBlock 故意跳过 —— 搜"text"经常误命中代码 / variable name
    static func plainText(of block: MarkdownDocument.Block) -> String? {
        switch block {
        case .heading(_, let content, _):
            return String(content.characters)
        case .paragraph(let content):
            return String(content.characters)
        case .bulletList(let items), .orderedList(let items):
            // 多 item 之间用换行连，让 occurrenceInBlock 跟跨 item 一致
            return items.map { String($0.characters) }.joined(separator: "\n")
        case .quote(let content):
            return String(content.characters)
        case .codeBlock, .horizontalRule, .spacer:
            return nil
        }
    }
}
