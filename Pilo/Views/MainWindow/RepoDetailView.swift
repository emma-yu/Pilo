import SwiftUI

struct RepoDetailView: View {

    let repo: Repository
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metaSection
                remotesSection
                statusSection
                actionsHint
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(repo.name)
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: 8) {
                if let branch = repo.currentBranch {
                    Text(branch)
                        .font(.piloMono)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cloudDivider.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                }
                if let d = repo.lastCommitDate {
                    Text("最后提交：\(RepoCard.relativeFormatter.localizedString(for: d, relativeTo: Date()))")
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "路径")
            Text(repo.path)
                .font(.piloMono)
                .foregroundStyle(Color.inkSecondary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var remotesSection: some View {
        if !repo.remotes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Remote")
                ForEach(repo.remotes, id: \.name) { remote in
                    HStack(spacing: 6) {
                        Text(remote.name)
                            .font(.piloMono)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.piloBlueLight.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                        Text(remote.displayHost)
                            .font(.piloBody)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "状态")
            HStack(spacing: 10) {
                if repo.aheadCount > 0 { StatusBadge(kind: .ahead(repo.aheadCount)) }
                if repo.behindCount > 0 { StatusBadge(kind: .behind(repo.behindCount)) }
                if repo.uncommittedCount > 0 { StatusBadge(kind: .uncommitted(repo.uncommittedCount)) }
                if !repo.hasWork && repo.behindCount == 0 { StatusBadge(kind: .synced) }
            }
        }
    }

    private var actionsHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "动作")
            Text("Push / Pull 等操作将在 Phase 5 实现。当前版本仅做发现与显示。")
                .font(.piloCaption)
                .foregroundStyle(Color.inkTertiary)
        }
    }
}
