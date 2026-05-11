import SwiftUI

/// 单个仓库行，用于菜单栏 popover 和主窗口左栏。
struct RepoCard: View {
    let repo: Repository
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            // 选中态左侧 3px 强调条；用 ZStack 而非边距以保持文本对齐
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? Color.piloBlue : Color.clear)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                statusDot
                    .padding(.leading, 8)
            }
            .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.piloSection)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(secondaryLine)
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            badge
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.piloBlue.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .hoverable(highlight: isSelected ? .clear : Color.piloBlue.opacity(0.06))
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: repo.path)])
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            Button {
                NSWorkspace.shared.open([URL(fileURLWithPath: repo.path)],
                                        withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                        configuration: NSWorkspace.OpenConfiguration(),
                                        completionHandler: nil)
            } label: {
                Label("在终端打开", systemImage: "terminal")
            }
            Divider()
            Button(role: .destructive) {
                appState.setHidden(true, repoId: repo.id)
            } label: {
                Label("隐藏此仓库", systemImage: "eye.slash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repo.row.\(repo.pathHash)")
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(dotColor.opacity(0.25), lineWidth: 2)
                    .frame(width: 14, height: 14)
            )
    }

    private var dotColor: Color {
        switch repo.statusSummary {
        case .synced:       .mintSafe
        case .ahead:        .amberWarn
        case .behind:       .lavenderInfo
        case .uncommitted:  .roseDanger
        }
    }

    private var secondaryLine: String {
        var parts: [String] = []
        if let b = repo.currentBranch { parts.append(b) }
        if let d = repo.lastCommitDate {
            parts.append(Self.relativeFormatter.localizedString(for: d, relativeTo: Date()))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var badge: some View {
        // 同时显示 ahead + uncommitted（之前只显示优先级最高的，导致 getihu 那种
        // "5 待提交 + 4 ↑" 的仓库丢了 ahead 数字，用户以为没法 push）
        HStack(spacing: 4) {
            if repo.aheadCount > 0 {
                StatusBadge(kind: .ahead(repo.aheadCount))
            }
            if repo.behindCount > 0 && repo.aheadCount == 0 {
                StatusBadge(kind: .behind(repo.behindCount))
            }
            if repo.uncommittedCount > 0 {
                StatusBadge(kind: .uncommitted(repo.uncommittedCount))
            }
            if !repo.hasWork && repo.behindCount == 0 {
                StatusBadge(kind: .synced)
            }
        }
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.unitsStyle = .full
        return f
    }()
}
