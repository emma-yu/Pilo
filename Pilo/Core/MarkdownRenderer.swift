import Foundation

/// 轻量 Markdown 解析器。
///
/// 设计原则：
///   - **Line-based state machine**，简单可维护
///   - inline 格式（`**bold**` / `*italic*` / `` `code` `` / `[link](url)`）委托给系统的
///     `AttributedString(markdown:)`，保证主流 markdown 兼容
///   - 块级（heading / list / code block / quote / hr）自己识别，便于应用 Pilo 字体
///   - **不支持**：表格 / 嵌套列表 / 图片（用户该用编辑器看）
///   - 文件 > 500KB → 拒绝渲染
enum MarkdownRenderer {

    static let maxFileBytes = 500_000
    static let maxLines = 5_000

    /// 主入口。失败 / 太大 → 返回 truncated MarkdownDocument。
    static func parse(_ source: String) -> MarkdownDocument {
        if source.isEmpty {
            return MarkdownDocument(blocks: [], truncated: false, totalLines: 0)
        }
        if source.utf8.count > maxFileBytes {
            return MarkdownDocument(blocks: [], truncated: true, totalLines: 0)
        }
        let lines = source.components(separatedBy: "\n")
        if lines.count > maxLines {
            return MarkdownDocument(blocks: [], truncated: true, totalLines: lines.count)
        }
        let parser = LineParser()
        for line in lines {
            parser.feed(line)
        }
        parser.flush()
        // 去掉首尾的 spacer（结尾空行 / 开头空行不应渲染成 spacer）
        var blocks = parser.blocks
        while case .spacer = blocks.first { blocks.removeFirst() }
        while case .spacer = blocks.last { blocks.removeLast() }
        return MarkdownDocument(blocks: blocks, truncated: false, totalLines: lines.count)
    }

    /// inline 段落用系统 markdown parser；失败 fallback 纯文本。
    static func parseInline(_ s: String) -> AttributedString {
        guard let attr = try? AttributedString(markdown: s, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )) else {
            return AttributedString(s)
        }
        return attr
    }
}

// MARK: - 行解析状态机

private final class LineParser {
    enum State {
        case none
        case codeBlock(language: String?)
        case paragraph
        case bulletList
        case orderedList
        case quote
    }

    var state: State = .none
    var buffer: [String] = []
    private(set) var blocks: [MarkdownDocument.Block] = []
    private var anchorCounter = 0

    func feed(_ line: String) {
        // 1) code block 状态机优先（内容不被进一步解析）
        if case .codeBlock = state {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // 关闭 code block
                if case .codeBlock(let lang) = state {
                    blocks.append(.codeBlock(language: lang, code: buffer.joined(separator: "\n")))
                }
                buffer = []
                state = .none
            } else {
                buffer.append(line)
            }
            return
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // 2) fence 进入 code block
        if trimmed.hasPrefix("```") {
            flush()
            let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            state = .codeBlock(language: lang.isEmpty ? nil : lang)
            buffer = []
            return
        }

        // 3) 空行：flush 并放 spacer
        if trimmed.isEmpty {
            flush()
            blocks.append(.spacer)
            return
        }

        // 4) heading: # / ## / ### 等
        if let level = headingLevel(of: trimmed) {
            flush()
            let content = String(trimmed.dropFirst(level + 1))   // "## title" → "title"
            let anchor = "h\(anchorCounter)"
            anchorCounter += 1
            blocks.append(.heading(
                level: level,
                content: MarkdownRenderer.parseInline(content),
                anchor: anchor
            ))
            return
        }

        // 5) horizontal rule（---、***、___）
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            flush()
            blocks.append(.horizontalRule)
            return
        }

        // 6) blockquote
        if trimmed.hasPrefix("> ") || trimmed == ">" {
            let payload = trimmed == ">" ? "" : String(trimmed.dropFirst(2))
            if case .quote = state {
                buffer.append(payload)
            } else {
                flush()
                state = .quote
                buffer = [payload]
            }
            return
        }

        // 7) unordered list
        if let item = unorderedListItem(in: trimmed) {
            if case .bulletList = state {
                buffer.append(item)
            } else {
                flush()
                state = .bulletList
                buffer = [item]
            }
            return
        }

        // 8) ordered list
        if let item = orderedListItem(in: trimmed) {
            if case .orderedList = state {
                buffer.append(item)
            } else {
                flush()
                state = .orderedList
                buffer = [item]
            }
            return
        }

        // 9) 普通段落
        if case .paragraph = state {
            buffer.append(trimmed)
        } else {
            flush()
            state = .paragraph
            buffer = [trimmed]
        }
    }

    func flush() {
        switch state {
        case .none, .codeBlock:
            break
        case .paragraph:
            let joined = buffer.joined(separator: " ")
            if !joined.isEmpty {
                blocks.append(.paragraph(content: MarkdownRenderer.parseInline(joined)))
            }
        case .bulletList:
            blocks.append(.bulletList(items: buffer.map(MarkdownRenderer.parseInline)))
        case .orderedList:
            blocks.append(.orderedList(items: buffer.map(MarkdownRenderer.parseInline)))
        case .quote:
            let joined = buffer.joined(separator: " ")
            blocks.append(.quote(content: MarkdownRenderer.parseInline(joined)))
        }
        buffer = []
        state = .none
    }

    // MARK: - helpers

    /// `# title` → 1, `## title` → 2 ... `###### title` → 6
    private func headingLevel(of trimmed: String) -> Int? {
        var count = 0
        for ch in trimmed {
            if ch == "#" {
                count += 1
                if count > 6 { return nil }
            } else if ch == " " && count > 0 {
                return count
            } else {
                return nil
            }
        }
        return nil
    }

    private func unorderedListItem(in trimmed: String) -> String? {
        for prefix in ["- ", "* ", "+ "] {
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
            }
        }
        return nil
    }

    /// `1. item` / `42. item` → 抽出 item
    private func orderedListItem(in trimmed: String) -> String? {
        var idx = trimmed.startIndex
        var sawDigit = false
        while idx < trimmed.endIndex, trimmed[idx].isASCII, trimmed[idx].isNumber {
            sawDigit = true
            idx = trimmed.index(after: idx)
        }
        guard sawDigit, idx < trimmed.endIndex, trimmed[idx] == "." else { return nil }
        idx = trimmed.index(after: idx)
        guard idx < trimmed.endIndex, trimmed[idx] == " " else { return nil }
        return String(trimmed[trimmed.index(after: idx)...])
    }
}
