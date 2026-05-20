import SwiftUI

/// Bear-vibe minimal repo row：2 行排版（名字 + 状态字），无 dot 无 chip 无箭头。
struct RepoCard: View {
    let repo: Repository
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(repo.name)
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.piloCaption)
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, PiloSpacing.s)
        .padding(.horizontal, PiloSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PiloRadius.small, style: .continuous)
                .fill(isSelected ? Color.piloBlue.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: repo.path)])
            } label: {
                Label(Copy.RepoList.revealInFinder(appState.language), systemImage: "folder")
            }
            Button {
                NSWorkspace.shared.open([URL(fileURLWithPath: repo.path)],
                                        withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                        configuration: NSWorkspace.OpenConfiguration(),
                                        completionHandler: nil)
            } label: {
                Label(Copy.RepoList.openInTerminal(appState.language), systemImage: "terminal")
            }
            Divider()
            Button(role: .destructive) {
                appState.setHidden(true, repoId: repo.id)
            } label: {
                Label(Copy.RepoList.hideRepository(appState.language), systemImage: "eye.slash")
            }
        }
        .hoverable(highlight: isSelected ? .clear : Color.piloBlue.opacity(0.05),
                   cornerRadius: PiloRadius.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repo.row.\(repo.pathHash)")
    }

    /// 一行小字总结状态：「↑ 2 · 待提交 5」
    private var statusLine: String {
        var parts: [String] = []
        if repo.aheadCount > 0      { parts.append("↑ \(repo.aheadCount)") }
        if repo.behindCount > 0     { parts.append("↓ \(repo.behindCount)") }
        if repo.uncommittedCount > 0 { parts.append(Copy.RepoList.repoUncommittedCount(appState.language, count: repo.uncommittedCount)) }
        if let b = repo.currentBranch, parts.isEmpty {
            parts.append(b)   // 没有需要处理的时显示分支
        }
        return parts.joined(separator: " · ")
    }

    private var statusTint: Color {
        switch repo.statusSummary {
        case .ahead:        return .amberWarn
        case .behind:       return .lavenderInfo
        case .uncommitted:  return .roseDanger
        case .synced:       return .inkSecondary
        }
    }

    /// 跨视图共享的相对时间格式器
    static func relativeFormatter(for lang: Language) -> RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: lang == .zh ? "zh_Hans_CN" : "en_US")
        f.unitsStyle = .full
        return f
    }
}
