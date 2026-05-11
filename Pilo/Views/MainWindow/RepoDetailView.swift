import SwiftUI
import AppKit

/// v3.3 邮局风 RepoDetailView：衬线大标题 + 金色 section 分隔 + 信纸 commit card + 大 CTA。
struct RepoDetailView: View {

    let repo: Repository
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    private var lang: Language { appState.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PiloSpacing.xl) {
                heroSection
                    .padding(.top, PiloSpacing.xl)

                SectionDivider(label: lang == .zh ? "— 待寄出的小信 —"
                                                  : "— letters to send —")

                commitsList

                actionsRow
                    .padding(.top, PiloSpacing.s)

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

    // MARK: - Hero（衬线大标题 + 路径斜体）

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: PiloSpacing.xs) {
            Text(repo.name)
                .font(.piloSerifHero)
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(heroMeta)
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private var heroMeta: String {
        var parts: [String] = [repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
        if let b = repo.currentBranch { parts.append(b) }
        if let d = repo.lastCommitDate {
            let formatter = RepoCard.relativeFormatter
            parts.append((lang == .zh ? "修改于 " : "edited ") + formatter.localizedString(for: d, relativeTo: Date()))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Commits 信纸卡片列表

    @ViewBuilder
    private var commitsList: some View {
        if repo.aheadCount == 0 {
            emptyCommitsState
        } else {
            VStack(spacing: PiloSpacing.xs) {
                // 真实 commit list 在 Phase 5 push dialog 才拉取；这里展示 placeholder rows
                ForEach(0..<min(repo.aheadCount, 3), id: \.self) { i in
                    commitPlaceholderRow(index: i)
                }
                if repo.aheadCount > 3 {
                    Text(lang == .zh ? "…还有 \(repo.aheadCount - 3) 个"
                                     : "…and \(repo.aheadCount - 3) more")
                        .font(.piloSerifCaption)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.top, PiloSpacing.xs)
                }
            }
        }
    }

    private func commitPlaceholderRow(index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PiloSpacing.s) {
            Text(String(format: "%07x", repo.pathHash.hashValue & 0xFFFFFFF).prefix(7))
                .font(.piloMono)
                .foregroundStyle(Color.piloGoldDark)
            Text(lang == .zh ? "（commit 详情会在推送时拉取）"
                              : "(commit details fetched at push time)")
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text((index == 0 ? "1h" : index == 1 ? "2h" : "3h"))
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkTertiary)
        }
        .piloCreamCard(padding: PiloSpacing.m)
    }

    private var emptyCommitsState: some View {
        HStack {
            Spacer()
            VStack(spacing: PiloSpacing.s) {
                if repo.uncommittedCount > 0 {
                    Text(lang == .zh
                        ? "有 \(repo.uncommittedCount) 个改动还没 commit"
                        : "\(repo.uncommittedCount) change\(repo.uncommittedCount == 1 ? "" : "s") not committed yet")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkSecondary)
                } else if repo.remotes.isEmpty {
                    Text(lang == .zh ? "还没有配置 remote" : "No remote configured")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    Text(lang == .zh ? "都同步啦 ✨" : "All caught up ✨")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.mintSafe)
                }
            }
            .padding(.vertical, PiloSpacing.l)
            Spacer()
        }
    }

    // MARK: - 操作行

    private var actionsRow: some View {
        HStack(spacing: PiloSpacing.s) {
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                    Text(Copy.Push.pushEntryButton(tone, lang))
                }
                .font(.piloSection)
            }
            .buttonStyle(.piloPrimary)
            .disabled(!canPush)

            Button {
                NSWorkspace.shared.open(
                    [URL(fileURLWithPath: repo.path)],
                    withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: nil
                )
            } label: {
                Text(lang == .zh ? "在终端打开" : "Open in Terminal")
            }
            .buttonStyle(.piloSecondary)

            Spacer()

            if !canPush, let hint = disabledReason {
                Text(hint)
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private var canPush: Bool {
        repo.currentBranch != nil && repo.aheadCount > 0 && !repo.remotes.isEmpty
    }

    private var disabledReason: String? {
        if repo.currentBranch == nil { return lang == .zh ? "detached HEAD" : "detached HEAD" }
        if repo.remotes.isEmpty { return lang == .zh ? "未配置 remote" : "no remote" }
        if repo.aheadCount == 0 && repo.uncommittedCount > 0 {
            return lang == .zh ? "先 git commit" : "git commit first"
        }
        if repo.aheadCount == 0 {
            return lang == .zh ? "无可推送" : "nothing to push"
        }
        return nil
    }
}
