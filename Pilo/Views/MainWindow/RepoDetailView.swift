import SwiftUI
import AppKit

struct RepoDetailView: View {

    let repo: Repository
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actionsRow
                metaSection
                remotesSection
                statusSection
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
        HStack(spacing: 10) {
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                Label(Copy.Push.pushEntryButton(tone), systemImage: "paperplane.fill")
                    .frame(minWidth: 100)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Color.piloBlue)
            .disabled(repo.aheadCount == 0 || repo.currentBranch == nil)
            .help(repo.aheadCount == 0 ? Copy.Push.pushDisabledHint : "")

            Button {
                NSWorkspace.shared.open([URL(fileURLWithPath: repo.path)],
                                        withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                        configuration: NSWorkspace.OpenConfiguration(),
                                        completionHandler: nil)
            } label: {
                Label("在终端打开", systemImage: "terminal")
            }
            .controlSize(.large)
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

}
