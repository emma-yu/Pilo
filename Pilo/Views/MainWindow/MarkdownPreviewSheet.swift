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

    /// TOC sidebar 全局展开偏好（per-app，跨文档生效）
    @AppStorage("docTocExpanded") private var tocExpanded: Bool = true

    // === Phase 4: 文档内搜索 ===
    @State private var searchActive = false
    @State private var searchQuery = ""
    @State private var searchHits: [MarkdownSearchEngine.Hit] = []
    @State private var currentHitIndex = 0
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            if searchActive {
                MarkdownSearchBar(
                    query: $searchQuery,
                    currentHitIndex: $currentHitIndex,
                    hitCount: searchHits.count,
                    lang: lang,
                    onClose: { closeSearch() },
                    focusBinding: $searchFieldFocused
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            content
        }
        // 可拖拽：默认 960×880，最小 720×600（再小布局崩），最大不限
        .frame(
            minWidth: 720,
            idealWidth: 960,
            maxWidth: .infinity,
            minHeight: 600,
            idealHeight: 880,
            maxHeight: .infinity
        )
        .background(Color.piloPaper.opacity(0.95))
        // macOS sheet 默认 NSWindow styleMask 不含 .resizable —— 手动开启让用户拖动
        .background(WindowResizableEnabler())
        .onChange(of: searchQuery) { _, newQuery in
            recomputeSearch(query: newQuery)
        }
        .onChange(of: currentHitIndex) { _, newIdx in
            guard searchHits.indices.contains(newIdx) else { return }
            withAnimation(.piloSpring) {
                scrolledBlockID = searchHits[newIdx].blockIndex
            }
        }
    }

    private func openSearch() {
        withAnimation(.piloSpring) { searchActive = true }
        // 100ms 让 transition 完成再 focus —— 避免动画期间焦点位置抖
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            searchFieldFocused = true
        }
    }

    private func closeSearch() {
        withAnimation(.piloSpring) {
            searchActive = false
            searchQuery = ""
        }
        searchHits = []
        currentHitIndex = 0
        searchFieldFocused = false
    }

    /// 当前 hit 在指定 block 内是第几次出现（0-based）；nil = 当前 hit 不在本 block
    private func currentOccurrenceFor(blockIndex: Int) -> Int? {
        guard searchActive,
              searchHits.indices.contains(currentHitIndex) else { return nil }
        let cur = searchHits[currentHitIndex]
        return cur.blockIndex == blockIndex ? cur.occurrenceInBlock : nil
    }

    private func recomputeSearch(query: String) {
        guard let mdDoc = appState.previewDocument else {
            searchHits = []
            currentHitIndex = 0
            return
        }
        let newHits = MarkdownSearchEngine.find(in: mdDoc, query: query)
        searchHits = newHits
        currentHitIndex = 0
        // 立即跳到第一个命中
        if let first = newHits.first {
            withAnimation(.piloSpring) {
                scrolledBlockID = first.blockIndex
            }
        }
    }

    // MARK: - Toolbar

    /// 当前 doc 是否有足够多 heading 值得显示 TOC（≥ 4 个）
    private var hasEnoughHeadings: Bool {
        guard let mdDoc = appState.previewDocument else { return false }
        return MarkdownTOC.extract(from: mdDoc.blocks).count >= MarkdownTOC.minHeadingsToShow
    }

    /// 实际是否渲染 TOC sidebar（用户偏好 AND doc 够长）
    private var shouldShowTOC: Bool {
        tocExpanded && hasEnoughHeadings
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            // TOC 切换 —— 仅当 doc 有足够 heading 才显示按钮
            if hasEnoughHeadings {
                Button(action: { withAnimation(.piloSpring) { tocExpanded.toggle() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tocExpanded ? Color.piloGoldDark : Color.inkSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .help(Copy.Docs.tocToggle(expanded: tocExpanded, lang))
            }

            Image(systemName: "envelope.open.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(doc.relativePath)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            // ⌘F 搜索 —— 不显示文字，只 icon；toggleable
            Button(action: { searchActive ? closeSearch() : openSearch() }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(searchActive ? Color.piloGoldDark : Color.inkSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: [.command])
            .help(lang == .zh ? "搜全文 (⌘F)" : "Search in document (⌘F)")

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
            HStack(spacing: 0) {
                if shouldShowTOC {
                    MarkdownTOCSidebar(
                        items: MarkdownTOC.extract(from: mdDoc.blocks),
                        lang: lang,
                        onSelect: { blockIndex in
                            withAnimation(.piloSpring) {
                                scrolledBlockID = blockIndex
                            }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                scrollableMarkdown(mdDoc)
            }
        } else {
            loadingState
        }
    }

    /// 内容滚动区 —— 独立出来跟 TOC 平级 HStack 排
    private func scrollableMarkdown(_ mdDoc: MarkdownDocument) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(mdDoc.blocks.enumerated()), id: \.offset) { i, block in
                    BlockView(
                        block: block,
                        searchQuery: searchActive ? searchQuery : "",
                        currentOccurrence: currentOccurrenceFor(blockIndex: i)
                    )
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
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            PostalWaveDots()
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
    /// 搜索 query —— 空字符串 = 不搜索（也不上色）
    var searchQuery: String = ""
    /// 当前 hit 在这个 block 内是第几次出现（0-based）；nil = 当前 hit 不在本 block
    var currentOccurrence: Int? = nil

    var body: some View {
        switch block {
        case .heading(let level, let content, _):
            heading(level: level, content: highlighted(content, occurrenceOffset: 0))
        case .paragraph(let content):
            Text(highlighted(content, occurrenceOffset: 0))
                .font(.system(size: 14))
                .foregroundStyle(Color.inkPrimary)
                .lineSpacing(4)
                .padding(.vertical, 4)
                .fixedSize(horizontal: false, vertical: true)
        case .codeBlock(_, let code):
            // 代码块不参与搜索（v1）—— 搜文本不搜代码
            codeBlock(code: code)
        case .bulletList(let items):
            // 列表 item 跨 item 的 occurrence 计数：累加前面 item 的命中数
            VStack(alignment: .leading, spacing: 4) {
                let itemHits = perItemOccurrenceCounts(items)
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark)
                            .frame(width: 12, alignment: .leading)
                        Text(highlighted(item, occurrenceOffset: itemHits[idx]))
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
                let itemHits = perItemOccurrenceCounts(items)
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Color.piloGoldDark)
                            .frame(width: 22, alignment: .trailing)
                        Text(highlighted(item, occurrenceOffset: itemHits[idx]))
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
                Text(highlighted(content, occurrenceOffset: 0))
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

    /// 给 AttributedString 加搜索高亮。
    /// `occurrenceOffset` 是这个 attr 在 block 内的"起始 occurrence 数"
    /// （列表 block 跨 item 共用一个 occurrence 计数，所以第 N 个 item 的 offset
    /// 是前 N-1 个 item 命中数之和）
    private func highlighted(_ attr: AttributedString, occurrenceOffset: Int) -> AttributedString {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return attr }

        var result = attr
        var cursor = result.startIndex
        var localOccurrence = 0
        let faint = Color.amberWarn.opacity(0.45)
        let bright = Color.amberWarn.opacity(0.85)

        while cursor < result.endIndex {
            let sub = result[cursor..<result.endIndex]
            guard let r = sub.range(of: q, options: .caseInsensitive) else { break }
            let globalOcc = occurrenceOffset + localOccurrence
            result[r].backgroundColor = (globalOcc == currentOccurrence) ? bright : faint
            cursor = r.upperBound
            localOccurrence += 1
        }
        return result
    }

    /// 列表 block 的每个 item 起始 occurrence 偏移
    /// e.g. items = ["foo bar foo", "bar foo"] query="foo" → counts = [2, 1] → offsets = [0, 2]
    private func perItemOccurrenceCounts(_ items: [AttributedString]) -> [Int] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(repeating: 0, count: items.count) }
        var offsets: [Int] = []
        var running = 0
        for item in items {
            offsets.append(running)
            let plain = String(item.characters).lowercased()
            var cursor = plain.startIndex
            while let r = plain.range(of: q.lowercased(), range: cursor..<plain.endIndex) {
                running += 1
                cursor = r.upperBound
            }
        }
        return offsets
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

// MARK: - NSWindow 可拖拽桥接

/// SwiftUI `.sheet` 默认 NSWindow 不含 `.resizable` —— 这个 NSViewRepresentable
/// 在 view 挂载后取到底层 NSWindow，给它加上 `.resizable` style mask，让用户
/// 能从右下角拖动 sheet 改尺寸。
///
/// 用法：作为 `.background(...)` 挂在 root view 即可（无 UI）。
private struct WindowResizableEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 等 view 挂上 window 后再改 styleMask
        DispatchQueue.main.async {
            applyResizable(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // sheet 重新呈现时也跑一次（保险）
        DispatchQueue.main.async {
            applyResizable(to: nsView.window)
        }
    }

    private func applyResizable(to window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
    }
}
