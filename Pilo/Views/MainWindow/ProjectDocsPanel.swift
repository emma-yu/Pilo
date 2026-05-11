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
    private var lang: Language { appState.language }

    var body: some View {
        if !docs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header
                rows
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
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.open")
                .font(.system(size: 13))
                .foregroundStyle(Color.piloGoldDark)
            Text(Copy.Docs.sectionTitle(count: docs.count, lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(docs) { doc in
                DocRow(doc: doc, repoPath: repoPath, lang: lang)
            }
        }
    }
}

private struct DocRow: View {
    let doc: RepoDoc
    let repoPath: String
    let lang: Language

    @Environment(AppState.self) private var appState
    @State private var isHovered = false

    var body: some View {
        // 主行 = 预览 sheet；hover 时右侧出现 ↗ 副按钮 = 外部编辑器
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

                // hover 时副按钮：用外部编辑器打开
                if isHovered {
                    Button(action: openInDefaultApp) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.piloBlueDark)
                    }
                    .buttonStyle(.plain)
                    .help(lang == .zh ? "用编辑器打开" : "Open in editor")
                    .transition(.opacity)
                } else {
                    // 占位让 row 宽度不跳
                    Image(systemName: "arrow.up.right.square")
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
    }

    private func presentPreview() {
        appState.presentPreview(for: doc, in: repoPath)
    }

    private func openInDefaultApp() {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        NSWorkspace.shared.open(fullPath)
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
