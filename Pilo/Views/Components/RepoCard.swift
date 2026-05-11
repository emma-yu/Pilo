import SwiftUI

/// 单个仓库行，用于菜单栏 popover 和主窗口左栏。
struct RepoCard: View {
    let repo: Repository
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            statusDot
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
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.piloBlue.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repo.row.\(repo.pathHash)")
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
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
        switch repo.statusSummary {
        case .ahead:        StatusBadge(kind: .ahead(repo.aheadCount))
        case .behind:       StatusBadge(kind: .behind(repo.behindCount))
        case .uncommitted:  StatusBadge(kind: .uncommitted(repo.uncommittedCount))
        case .synced:       StatusBadge(kind: .synced)
        }
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.unitsStyle = .full
        return f
    }()
}
