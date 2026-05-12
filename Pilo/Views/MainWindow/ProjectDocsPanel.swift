import SwiftUI
import AppKit

/// 项目文档面板：详情面板底部，仓库根 + docs/ 里的"项目知识"。
///
/// 显示规则：docs 为空 → 不显示（不挤占空间）
/// 点击行 → 用 NSWorkspace 打开默认编辑器（VS Code / Cursor / 等）
struct ProjectDocsPanel: View {

    let repoPath: String
    let docs: [RepoDoc]

    @Environment(AppState.self) private var appState
    @State private var isExpanded: Bool = false

    private var lang: Language { appState.language }

    /// 默认折叠的展示行数。
    private static let collapsedTop = 12

    private var visibleDocs: [RepoDoc] {
        if isExpanded || docs.count <= Self.collapsedTop {
            return docs
        }
        return Array(docs.prefix(Self.collapsedTop))
    }

    var body: some View {
        if !docs.isEmpty || !appState.currentHiddenDocs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !docs.isEmpty {
                    header
                    rows
                    if docs.count > Self.collapsedTop {
                        expandToggle
                            .padding(.top, 6)
                    }
                }
                if !appState.currentHiddenDocs.isEmpty {
                    HiddenDocsFooter(
                        hiddenDocs: appState.currentHiddenDocs,
                        repoPath: repoPath,
                        lang: lang,
                        hasVisibleAbove: !docs.isEmpty
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.creamBg.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cloudDivider.opacity(0.6), lineWidth: 0.5)
            )
            // 切 repo 时重置展开态（避免一个 repo 展开了状态 leak 到另一个）
            .onChange(of: repoPath) { _, _ in isExpanded = false }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // 邮票 icon —— "项目文档 = 项目的集邮册" 装饰
            Image("PostalStamp")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            Text(Copy.Docs.sectionTitle(count: docs.count, lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(visibleDocs) { doc in
                DocRow(doc: doc, repoPath: repoPath, lang: lang)
            }
        }
    }

    @ViewBuilder
    private var expandToggle: some View {
        let more = docs.count - Self.collapsedTop
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                Text(isExpanded
                     ? Copy.Docs.collapseToTop(Self.collapsedTop, lang)
                     : Copy.Docs.expandAll(more: more, lang))
                    .font(.piloSerifCaption)
            }
            .foregroundStyle(Color.piloGoldDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.piloGold.opacity(0.3),
                            style: StrokeStyle(lineWidth: 0.6, dash: [3, 2]))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DocRow: View {
    let doc: RepoDoc
    let repoPath: String
    let lang: Language

    @Environment(AppState.self) private var appState
    @State private var isHovered = false

    var body: some View {
        // 主行 = 预览 sheet；hover 时右侧出现 ↗ + ⋯ 副按钮
        Button(action: presentPreview) {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: doc.kind))
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor(for: doc.kind))
                    .frame(width: 16)

                Text(doc.relativePath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Text(doc.displaySize)
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.inkTertiary)

                Text(Copy.Docs.relativeModified(doc.modifiedAt, lang))
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.inkTertiary)
                    .frame(minWidth: 70, alignment: .trailing)

                // hover 时副按钮组：↗ 外部编辑器 + 📥 收进抽屉
                // 移除 ⋯ —— 右键 contextMenu 已足够；邮局世界不该出现工程符号
                if isHovered {
                    Button(action: openInDefaultApp) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.piloBlueDark)
                    }
                    .buttonStyle(.plain)
                    .help(lang == .zh ? "用编辑器打开" : "Open in editor")
                    .transition(.opacity)

                    Button(action: hideThis) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.piloGoldDark)
                    }
                    .buttonStyle(.plain)
                    .help(Copy.Docs.setAsideHint(lang))
                    .transition(.opacity)
                } else {
                    // 占位让 row 宽度不跳
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.clear)
                    Image(systemName: "archivebox")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.clear)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.piloPaper.opacity(0.7) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovered }
        }
        .help(Copy.Docs.rowHint(lang))
        .contextMenu { rowMenuContent }
    }

    /// 右键 menu 内容（也用在 ⋯ button 上，避免重复）
    @ViewBuilder
    private var rowMenuContent: some View {
        Button {
            presentPreview()
        } label: {
            Label(lang == .zh ? "在 Pilo 里预览" : "Preview in Pilo",
                  systemImage: "envelope.open")
        }
        Button {
            openInDefaultApp()
        } label: {
            Label(Copy.Preview.openInEditor(lang), systemImage: "arrow.up.right.square")
        }
        Button {
            showInFinder()
        } label: {
            Label(Copy.Docs.showInFinder(lang), systemImage: "folder")
        }
        Divider()
        Button {
            hideThis()
        } label: {
            Label(Copy.Docs.hideAction(lang), systemImage: "archivebox")
        }
    }

    private func presentPreview() {
        appState.presentPreview(for: doc, in: repoPath)
    }

    private func openInDefaultApp() {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        NSWorkspace.shared.open(fullPath)
    }

    private func showInFinder() {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        NSWorkspace.shared.activateFileViewerSelecting([fullPath])
    }

    private func hideThis() {
        guard let repoId = appState.repositories.first(where: { $0.path == repoPath })?.id else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            appState.hideDoc(doc, repoId: repoId)
        }
    }

    private func iconName(for kind: RepoDoc.Kind) -> String {
        switch kind {
        case .readme:         return "doc.text.fill"
        case .changelog:      return "scroll.fill"
        case .todo:           return "checklist"
        case .prd:            return "doc.richtext.fill"
        case .architecture:   return "square.stack.3d.up.fill"
        case .contributing:   return "person.2.fill"
        case .license:        return "doc.badge.gearshape"
        case .notes:          return "note.text"
        case .aiInstructions: return "sparkles"
        case .generic:        return "doc.text"
        }
    }

    private func iconColor(for kind: RepoDoc.Kind) -> Color {
        switch kind {
        case .readme:         return .piloBlue
        case .changelog:      return .piloGoldDark
        case .todo:           return .amberWarn
        case .prd:            return .lavenderInfo
        case .architecture:   return .piloBlueDark
        case .contributing:   return .mintSafe
        case .license:        return .inkSecondary
        case .notes:          return .inkSecondary
        case .aiInstructions: return .piloAccent
        case .generic:        return .inkTertiary
        }
    }
}

// MARK: - 已藏起的文档 footer

private struct HiddenDocsFooter: View {
    let hiddenDocs: [RepoDoc]
    let repoPath: String
    let lang: Language
    let hasVisibleAbove: Bool

    @Environment(AppState.self) private var appState
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 上方分隔：金色 OrnamentDivider 而非纯灰线，进入"邮局抽屉"的仪式感
            if hasVisibleAbove {
                OrnamentDivider(width: 160)
                    .padding(.vertical, 12)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hiddenDocs.isEmpty ? "archivebox" : "archivebox.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.piloGoldDark)
                    Text(Copy.Docs.hiddenSectionHeader(count: hiddenDocs.count, lang))
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Text(isOpen ? Copy.Docs.hiddenSectionToggleHide(lang)
                                    : Copy.Docs.hiddenSectionToggleShow(lang))
                            .font(.piloSerifCaption)
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.piloGoldDark)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 2) {
                    ForEach(hiddenDocs) { doc in
                        HiddenDocRow(doc: doc, repoPath: repoPath, lang: lang)
                    }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// 隐藏列表里的单行——左侧带"暂搁"小邮戳 + 金色"重新投递"文字链
private struct HiddenDocRow: View {
    let doc: RepoDoc
    let repoPath: String
    let lang: Language

    @Environment(AppState.self) private var appState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // 暂搁邮戳：italic Songti + 虚线 border + 轻微旋转，邮局信件上的"do not deliver"印章
            pausedStamp

            Image(systemName: "envelope")
                .font(.system(size: 11))
                .foregroundStyle(Color.inkTertiary)
                .frame(width: 14)

            Text(doc.relativePath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(Copy.Docs.relativeModified(doc.modifiedAt, lang))
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkTertiary)

            Button {
                guard let repoId = appState.repositories.first(where: { $0.path == repoPath })?.id else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.unhideDoc(doc, repoId: repoId)
                }
            } label: {
                Text(Copy.Docs.unhideAction(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.piloGoldDark)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .opacity(0.78)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.piloPaper.opacity(0.5) : Color.clear)
        )
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovered }
        }
    }

    /// "暂搁" / "PAUSED" 小邮戳：italic Songti + 虚线 stamp 边框 + -6° 旋转
    private var pausedStamp: some View {
        Text(Copy.Docs.setAsideStamp(lang))
            .font(.piloSerifCaption)
            .italic()
            .foregroundStyle(Color.stampRed.opacity(0.7))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.stampRed.opacity(0.55),
                            style: StrokeStyle(lineWidth: 0.6, dash: [2, 1.5]))
            )
            .rotationEffect(.degrees(-6))
            .frame(width: 36)
    }
}
