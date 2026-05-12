import SwiftUI
import AppKit

/// Markdown 预览 sheet —— 点 ProjectDocsPanel 的 doc 行后弹出。
///
/// 邮局美学：信纸黄 bg + Songti SC 衬线标题 + 金色 hairline + 信封 icon
/// 内容渲染：自写 line-based parser，inline 用 AttributedString(markdown:)
/// 容错：太长 / 不是文本 / 找不到 / 空 → 友好态卡片
struct MarkdownPreviewSheet: View {

    let doc: RepoDoc
    let repoPath: String

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    /// 复制全文后短暂显示 ✓ 反馈
    @State private var justCopied = false

    /// 当前可见的 top block index —— `.scrollPosition(id:)` 双向绑定
    /// onAppear 恢复 → 滚动到 saved；用户滚动 → 实时跟随 → onDisappear 存盘
    @State private var scrolledBlockID: Int?
    /// 防止 onAppear 多次触发恢复（保险，理论上 onAppear 只触发一次）
    @State private var hasRestoredScroll = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            content
        }
        .frame(width: 720, height: 820)
        .background(Color.piloPaper.opacity(0.95))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(doc.relativePath)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            // 誊抄全文 —— ⌘C 通用快捷键被 textSelection 抢了；用专门按钮
            Button(action: copyFullText) {
                HStack(spacing: 4) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(justCopied
                         ? (lang == .zh ? "已誊抄" : "Copied")
                         : (lang == .zh ? "誊抄" : "Copy"))
                        .font(.piloSerifCaption)
                }
                .foregroundStyle(justCopied ? Color.mintSafe : Color.piloGoldDark)
            }
            .buttonStyle(.plain)
            .help(lang == .zh ? "把全文复制到剪贴板" : "Copy full text to clipboard")

            Button(action: openInEditor) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                    Text(Copy.Preview.openInEditor(lang))
                        .font(.piloSerifCaption)
                }
                .foregroundStyle(Color.piloBlueDark)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: [.command])

            Button(action: { appState.dismissPreview() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.cloudDivider.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help(Copy.Preview.close(lang))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let err = appState.previewError {
            errorState(err)
        } else if let mdDoc = appState.previewDocument {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mdDoc.blocks.enumerated()), id: \.offset) { i, block in
                        BlockView(block: block)
                            .id(i)   // .scrollPosition target —— blockIndex 作 ID
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledBlockID)
            .onAppear {
                // 恢复上次滚动位置
                guard !hasRestoredScroll, !mdDoc.blocks.isEmpty else { return }
                hasRestoredScroll = true
                if let saved = DocReadingMemory.savedBlockIndex(
                    repoPath: repoPath,
                    docRelativePath: doc.relativePath
                ), saved > 0, saved < mdDoc.blocks.count {
                    scrolledBlockID = saved
                }
            }
            .onDisappear {
                // 保存当前位置 —— 即便是 0（用户主动滚回顶就该记住）
                if let id = scrolledBlockID, id >= 0 {
                    DocReadingMemory.save(
                        blockIndex: id,
                        repoPath: repoPath,
                        docRelativePath: doc.relativePath
                    )
                }
            }
        } else {
            loadingState
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.small)
                .tint(Color.piloGoldDark)
            Text(Copy.Preview.loading(lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorState(_ err: AppState.PreviewError) -> some View {
        let (title, body, icon): (String, String, String) = {
            switch err {
            case .tooLarge:
                return (Copy.Preview.errorTooLargeTitle(lang),
                        Copy.Preview.errorTooLargeBody(lang),
                        "doc.text.magnifyingglass")
            case .notText:
                return (Copy.Preview.errorNotTextTitle(lang),
                        Copy.Preview.errorNotTextBody(lang),
                        "doc.questionmark")
            case .fileNotFound:
                return (Copy.Preview.errorNotFoundTitle(lang),
                        Copy.Preview.errorNotFoundBody(lang),
                        "doc.badge.ellipsis")
            case .empty:
                return (Copy.Preview.errorEmptyTitle(lang),
                        Copy.Preview.errorEmptyBody(lang),
                        "doc")
            }
        }()
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.piloGoldDark.opacity(0.6))
            Text(title)
                .font(.piloSerifTitle)
                .foregroundStyle(Color.inkPrimary)
            Text(body)
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if err == .tooLarge || err == .notText {
                Button(action: openInEditor) {
                    Text(Copy.Preview.openInEditor(lang))
                        .font(.piloSerifSubtitle)
                }
                .buttonStyle(MarkdownErrorButtonStyle())
                .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openInEditor() {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        NSWorkspace.shared.open(fullPath)
        appState.dismissPreview()
    }

    /// 誊抄全文到剪贴板。失败静默（用户看不到 ✓ 就是失败了 —— 比 toast 更克制）
    private func copyFullText() {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        guard let text = try? String(contentsOf: fullPath, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.piloHover) { justCopied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.piloHover) { justCopied = false }
            }
        }
    }
}

// MARK: - Block 渲染

private struct BlockView: View {
    let block: MarkdownDocument.Block

    var body: some View {
        switch block {
        case .heading(let level, let content, _):
            heading(level: level, content: content)
        case .paragraph(let content):
            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(4)
                .padding(.vertical, 4)
                .fixedSize(horizontal: false, vertical: true)
        case .codeBlock(_, let code):
            codeBlock(code: code)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark)
                            .frame(width: 12, alignment: .leading)
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 8)
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color.piloGoldDark)
                            .frame(width: 22, alignment: .trailing)
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, 8)
        case .quote(let content):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.piloGold)
                    .frame(width: 2)
                Text(content)
                    .font(.custom("Songti SC", size: 14).italic())
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.leading, 6)
        case .horizontalRule:
            Rectangle()
                .fill(Color.piloGold.opacity(0.35))
                .frame(height: 0.5)
                .padding(.vertical, 14)
        case .spacer:
            Spacer().frame(height: 8)
        }
    }

    @ViewBuilder
    private func heading(level: Int, content: AttributedString) -> some View {
        switch level {
        case 1:
            VStack(alignment: .leading, spacing: 6) {
                Text(content)
                    .font(.custom("Songti SC", size: 26).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                Rectangle()
                    .fill(Color.piloGold.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.top, 14)
            .padding(.bottom, 8)
        case 2:
            Text(content)
                .font(.custom("Songti SC", size: 20).weight(.medium))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 12)
                .padding(.bottom, 4)
        case 3:
            Text(content)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 10)
                .padding(.bottom, 2)
        default:
            Text(content)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 8)
                .padding(.bottom, 2)
        }
    }

    private func codeBlock(code: String) -> some View {
        Text(code)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.inkPrimary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.piloPaperBorder.opacity(0.6), lineWidth: 0.5)
            )
            .padding(.vertical, 6)
    }
}

// MARK: - Error 状态的按钮 style

private struct MarkdownErrorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(Color.piloBlueDark)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.piloBlue.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.piloBlue.opacity(0.4), lineWidth: 0.5)
            )
    }
}
