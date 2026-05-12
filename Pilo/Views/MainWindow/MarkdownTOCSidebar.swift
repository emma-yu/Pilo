import SwiftUI

/// MarkdownPreviewSheet 左侧折叠 TOC。
///
/// 渲染规则：
///   - 仅 heading blocks 进入 TOC
///   - 按 level 缩进：h1=0, h2=12, h3=24, h4+=36
///   - 字号按 level 递减：h1=13/medium, h2=12/regular, h3+=11/regular
///   - hover piloGoldDark 文字 + 极淡 piloGold 背景
///   - 点击 → caller 收到 blockIndex，自己处理滚动
///
/// 顶部"— 目 录 —" 衬线 italic gold + 极淡 gold 渐变 hairline，跟 SectionDivider 同语调
struct MarkdownTOCSidebar: View {

    let items: [TOCItem]
    let lang: Language
    let onSelect: (Int) -> Void

    @State private var hoveredID: Int?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 "— 目 录 —" label
            HStack(spacing: 6) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.piloGold.opacity(0), Color.piloGold.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                Text(Copy.Docs.tocTitle(lang))
                    .font(.piloSerifLabel)
                    .foregroundStyle(Color.piloGoldDark)
                    .tracking(1.5)
                    .fixedSize()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.piloGold.opacity(0.6), Color.piloGold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // 列表
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        Button(action: { onSelect(item.blockIndex) }) {
                            tocRow(item)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredID = hovering ? item.blockIndex : nil
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 180)
        .background(Color.piloPaper.opacity(0.55))
        .overlay(alignment: .trailing) {
            // 右侧极淡金线分隔
            Rectangle()
                .fill(Color.piloGold.opacity(0.3))
                .frame(width: 0.5)
        }
    }

    private func tocRow(_ item: TOCItem) -> some View {
        let isHovered = hoveredID == item.blockIndex
        return HStack(spacing: 0) {
            // 缩进
            Spacer().frame(width: indentation(for: item.level))
            Text(item.text)
                .font(rowFont(for: item.level))
                .foregroundStyle(isHovered ? Color.piloGoldDark : Color.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHovered ? Color.piloGold.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }

    private func indentation(for level: Int) -> CGFloat {
        switch level {
        case 1:  return 0
        case 2:  return 12
        case 3:  return 24
        default: return 36
        }
    }

    private func rowFont(for level: Int) -> Font {
        switch level {
        case 1:  return .system(size: 13, weight: .medium)
        case 2:  return .system(size: 12, weight: .regular)
        default: return .system(size: 11, weight: .regular)
        }
    }
}

/// 单条 TOC 项 —— headings extractor 输出
struct TOCItem: Hashable, Identifiable, Sendable {
    let blockIndex: Int
    let level: Int
    let text: String
    var id: Int { blockIndex }
}

/// 从 markdown blocks 提取出 TOC items（按文档顺序）。
/// `nonisolated` 静态函数，方便测试 + view 外调用。
enum MarkdownTOC {
    static func extract(from blocks: [MarkdownDocument.Block]) -> [TOCItem] {
        var items: [TOCItem] = []
        for (i, block) in blocks.enumerated() {
            if case .heading(let level, let content, _) = block {
                let plain = String(content.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !plain.isEmpty else { continue }
                items.append(TOCItem(blockIndex: i, level: level, text: plain))
            }
        }
        return items
    }

    /// 触发 TOC 显示的 heading 数量阈值。低于此值 sidebar 隐藏 + toggle 隐藏。
    static let minHeadingsToShow = 4
}
