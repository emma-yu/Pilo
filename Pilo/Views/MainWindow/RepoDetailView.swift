import SwiftUI
import AppKit

struct RepoDetailView: View {

    let repo: Repository
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header.piloCard()
                actionsRow.piloCard()
                metaSection.piloCard()
                remotesSection
                statusSection.piloCard()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: Binding(
            get: { appState.pushSession },
            set: { appState.pushSession = $0 }
        )) { _ in
            PushConfirmDialog(
                session: Binding(
                    get: { appState.pushSession },
                    set: { appState.pushSession = $0 }
                ),
                onDismiss: { appState.dismissPushSession() }
            )
        }
    }

    private var actionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await appState.beginPushSession(for: repo) }
                } label: {
                    Label(Copy.Push.pushEntryButton(tone), systemImage: "paperplane.fill")
                        .font(.piloSection)
                        .frame(minWidth: 110)
                }
                .buttonStyle(.piloPrimary)
                .disabled(!canPush)

                Button {
                    NSWorkspace.shared.open([URL(fileURLWithPath: repo.path)],
                                            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                            configuration: NSWorkspace.OpenConfiguration(),
                                            completionHandler: nil)
                } label: {
                    Label("在终端打开", systemImage: "terminal")
                        .font(.piloBody)
                }
                .buttonStyle(.piloSecondary)
            }

            if let hint = pushDisabledReason {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.lavenderInfo)
                    Text(hint)
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    private var canPush: Bool {
        repo.currentBranch != nil && repo.aheadCount > 0 && !repo.remotes.isEmpty
    }

    /// 当 push 按钮 disabled 时显示的明确理由（按优先级）
    private var pushDisabledReason: String? {
        if repo.currentBranch == nil {
            return "当前不在任何分支上（detached HEAD），无法 push"
        }
        if repo.remotes.isEmpty {
            return "还没有配置 remote。先在终端运行 `git remote add origin <url>`"
        }
        if repo.aheadCount == 0 && repo.uncommittedCount > 0 {
            return "有 \(repo.uncommittedCount) 个改动还没 commit。先 `git commit` 才能 push"
        }
        if repo.aheadCount == 0 {
            return "没有可推送的 commit"
        }
        return nil
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.piloBlueLight.opacity(0.45), in: RoundedRectangle(cornerRadius: 5))
                            .foregroundStyle(Color.piloBlueDark)
                        Text(remote.displayHost)
                            .font(.piloBody)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .piloCard()
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

}
