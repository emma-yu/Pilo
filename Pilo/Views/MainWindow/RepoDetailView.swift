import SwiftUI
import AppKit

/// Bear-vibe RepoDetailView：居中编辑器布局，max-width 680，无 card，靠留白 + hairline。
struct RepoDetailView: View {

    let repo: Repository
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PiloSpacing.xl) {
                heroCard
                    .padding(.top, PiloSpacing.xl)

                actionCard

                metaSection

                Spacer(minLength: PiloSpacing.xxxl)
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, PiloSpacing.xl)
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

    // MARK: - Hero card（信纸般的封面卡片 + 角落折角装饰）

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .center, spacing: PiloSpacing.s) {
                Text(repo.name)
                    .font(.piloHero)
                    .tracking(-0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(heroSubtitle)
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, PiloSpacing.xl)
            .piloCard(padding: PiloSpacing.xl, elevation: .elevated)

            // 右上角：信封折角装饰
            EnvelopeCorner(size: 32, fillColor: Color.piloCream, foldColor: Color.piloBlueLight)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: PiloRadius.card
                ))
                .padding(.top, 0)
                .padding(.trailing, 0)
        }
    }

    private var heroSubtitle: String {
        var parts: [String] = []
        if let b = repo.currentBranch {
            parts.append(b)
        }
        if let d = repo.lastCommitDate {
            parts.append("修改于 " + RepoCard.relativeFormatter.localizedString(for: d, relativeTo: Date()))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 主操作 card（居中大 CTA + 次要 text-link）

    private var actionCard: some View {
        actionSection
            .piloCard(padding: PiloSpacing.xl, elevation: .normal)
    }

    private var actionSection: some View {
        VStack(spacing: PiloSpacing.l) {
            // 一句话状态描述
            if repo.aheadCount > 0, repo.currentBranch != nil, let remote = repo.remotes.first {
                Text("\(repo.aheadCount) 个 commit 等着飞往\n\(remote.displayHost)")
                    .font(.piloBody)
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, PiloSpacing.xl)
            } else if repo.uncommittedCount > 0 {
                Text("\(repo.uncommittedCount) 个改动还没 commit")
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
            } else if repo.remotes.isEmpty {
                Text("还没有配置 remote")
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                Text("已同步")
                    .font(.piloBody)
                    .foregroundStyle(Color.mintSafe)
            }

            // 主 CTA
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                Label("推送", systemImage: "paperplane.fill")
                    .font(.piloSection)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.piloPrimary)
            .disabled(!canPush)

            // 次要 text-link
            Button {
                NSWorkspace.shared.open(
                    [URL(fileURLWithPath: repo.path)],
                    withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: nil
                )
            } label: {
                Text("在终端打开 →")
            }
            .buttonStyle(.piloTextLink)
        }
        .frame(maxWidth: .infinity)
    }

    private var canPush: Bool {
        repo.currentBranch != nil && repo.aheadCount > 0 && !repo.remotes.isEmpty
    }

    // MARK: - Meta 信息卡片（label + 内容编辑器样式）

    private var metaSection: some View {
        metaContent
            .piloCard(padding: PiloSpacing.xl, elevation: .normal)
    }

    private var metaContent: some View {
        VStack(alignment: .leading, spacing: PiloSpacing.xl) {
            metaRow(label: "路径", content: Text(repo.path).font(.piloMono))

            if !repo.remotes.isEmpty {
                metaRow(label: "REMOTE", content: remotesList)
            }

            metaRow(label: "状态", content: statusLine)
        }
    }

    private func metaRow<C: View>(label: String, content: C) -> some View {
        VStack(alignment: .leading, spacing: PiloSpacing.xs) {
            Text(label.uppercased())
                .font(.piloLabel)
                .tracking(2.0)
                .foregroundStyle(Color.inkTertiary)
            content
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private var remotesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(repo.remotes, id: \.name) { remote in
                HStack(spacing: 8) {
                    Text(remote.name)
                        .font(.piloBody)
                        .foregroundStyle(Color.piloBlue)
                    Text("→")
                        .font(.piloBody)
                        .foregroundStyle(Color.inkTertiary)
                    Text(remote.displayHost)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        let parts = statusParts
        if parts.isEmpty {
            Text("已同步")
                .font(.piloBody)
                .foregroundStyle(Color.mintSafe)
        } else {
            Text(parts.joined(separator: "   ·   "))
                .font(.piloBody)
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private var statusParts: [String] {
        var p: [String] = []
        if repo.aheadCount > 0      { p.append("↑ \(repo.aheadCount)") }
        if repo.behindCount > 0     { p.append("↓ \(repo.behindCount)") }
        if repo.uncommittedCount > 0 { p.append("\(repo.uncommittedCount) 待提交") }
        return p
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.cloudDivider.opacity(0.6))
            .frame(height: 1)
    }
}
