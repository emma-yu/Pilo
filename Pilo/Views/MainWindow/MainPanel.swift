import SwiftUI
import AppKit

/// v3.4 主面板：完全照 HTML 参考 scene 2 复刻——
/// 单卡片包顶部 header + 内部 2 列网格（180pt sidebar + flex detail）+ 信纸 commit 卡 + 按钮行
struct MainPanel: View {

    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        // 窗口本身就是面板——header 直接坐在窗口顶部，下方 2 栏铺满
        VStack(spacing: 0) {
            PanelHeader()
            Rectangle()
                .fill(Color.cloudDivider)
                .frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                PanelSidebar()
                    .frame(width: 220)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(Color.cloudDivider)
                    .frame(width: 1)
                PanelDetail()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paperCard)
    }
}

// MARK: - Panel Header（⭐金星 + 衬线标题 + 健康胶囊）

private struct PanelHeader: View {
    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        HStack(spacing: 10) {
            // 金色 5 角星图标
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.piloGold)

            Text(lang == .zh ? "Pilo · 我的小邮局" : "Pilo · My Post Office")
                .font(.piloSerifLabel.weight(.medium))
                .foregroundStyle(Color.inkPrimary)
                .tracking(0.3)

            Spacer()

            healthPill
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color("CreamBg").opacity(0.35))
    }

    private var healthPill: some View {
        let healthy = appState.gitExecutablePath != nil
        let text = healthy
            ? (lang == .zh ? "SSH · Token · 一切都好" : "SSH · Token · All good")
            : (lang == .zh ? "未找到 git" : "git missing")
        let tint: Color = healthy ? .stampMint : .roseDanger

        return HStack(spacing: 4) {
            Image(systemName: healthy ? "checkmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Panel Sidebar（斜体宋体分组 + dot + name + count）

private struct PanelSidebar: View {
    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        ZStack {
            // 微微 tint 的 cream 背景（HTML: rgba(238,234,228,0.22)）
            Color("CreamBg").opacity(0.22)

            VStack(alignment: .leading, spacing: 0) {
                if !appState.activeRepos.isEmpty {
                    sidebarLabel(
                        text: (lang == .zh ? "活跃 · " : "Active · ") + "\(appState.activeRepos.count)"
                    )
                    .padding(.top, PiloSpacing.s)
                    .padding(.bottom, PiloSpacing.xs)

                    ForEach(appState.activeRepos) { repo in
                        sidebarItem(repo)
                    }
                }

                if !appState.sleepingRepos.isEmpty {
                    sidebarLabel(
                        text: (lang == .zh ? "沉睡 · " : "Sleeping · ") + "\(appState.sleepingRepos.count)"
                    )
                    .padding(.top, PiloSpacing.m)
                    .padding(.bottom, PiloSpacing.xs)

                    ForEach(appState.sleepingRepos) { repo in
                        sidebarItem(repo)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func sidebarLabel(text: String) -> some View {
        Text(text)
            .font(.piloSerifCaption)
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 14)
    }

    private func sidebarItem(_ repo: Repository) -> some View {
        let isActive = repo.id == appState.selectedRepoId
        return Button {
            appState.selectRepo(repo.id)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(dotColor(for: repo))
                    .frame(width: 7, height: 7)
                Text(repo.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if let count = countLabel(for: repo) {
                    Text(count)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.piloBlue)
                }
            }
            .padding(.horizontal, isActive ? 12 : 14)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? Color.piloBlue.opacity(0.12)
                    : Color.clear
            )
            .overlay(alignment: .leading) {
                if isActive {
                    Rectangle()
                        .fill(Color.piloBlue)
                        .frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dotColor(for repo: Repository) -> Color {
        switch repo.statusSummary {
        case .ahead:       return .amberWarn
        case .behind:      return .lavenderInfo
        case .uncommitted: return .roseDanger
        case .synced:
            return appState.sleepingRepos.contains(where: { $0.id == repo.id })
                ? .inkTertiary
                : .mintSafe
        }
    }

    private func countLabel(for repo: Repository) -> String? {
        if repo.aheadCount > 0 { return "\(repo.aheadCount)↑" }
        if repo.uncommittedCount > 0 { return "\(repo.uncommittedCount)" }
        return nil
    }
}

// MARK: - Panel Detail（衬线 hero + section + 信纸 commit + 操作按钮）

private struct PanelDetail: View {
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    private var lang: Language { appState.language }

    var body: some View {
        if let repo = currentRepo {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 衬线标题
                    Text(repo.name)
                        .font(.piloSerifTitle)
                        .tracking(0.3)
                        .foregroundStyle(Color.inkPrimary)

                    // mono 元信息
                    Text(metaLine(for: repo))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.top, 4)

                    SectionDivider(label: sectionLabel(for: repo))
                        .padding(.top, 18)
                        .padding(.bottom, 8)

                    commitsList(for: repo)

                    actionsRow(for: repo)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            emptyDetail
        }
    }

    private var currentRepo: Repository? {
        guard let id = appState.selectedRepoId else {
            // 默认选第一个 active
            return appState.activeRepos.first ?? appState.sortedRepos.first
        }
        return appState.repositories.first(where: { $0.id == id })
    }

    private func metaLine(for repo: Repository) -> String {
        var parts: [String] = [repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
        if let b = repo.currentBranch { parts.append(b) }
        if let d = repo.lastCommitDate {
            parts.append(
                (lang == .zh ? "修改于 " : "edited ")
                + RepoCard.relativeFormatter.localizedString(for: d, relativeTo: Date())
            )
        }
        return parts.joined(separator: " · ")
    }

    private func sectionLabel(for repo: Repository) -> String {
        if repo.aheadCount > 0 {
            return lang == .zh ? "— 待寄出的小信 —" : "— letters to send —"
        }
        if repo.uncommittedCount > 0 {
            return lang == .zh ? "— 工作区改动 —" : "— working changes —"
        }
        return lang == .zh ? "— 一切安好 —" : "— all is well —"
    }

    @ViewBuilder
    private func commitsList(for repo: Repository) -> some View {
        if repo.aheadCount > 0 {
            if appState.currentCommits.isEmpty {
                Text(lang == .zh ? "正在拉取 commit..." : "Loading commits...")
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.vertical, PiloSpacing.s)
            } else {
                VStack(spacing: 7) {
                    ForEach(appState.currentCommits.prefix(8)) { c in
                        commitRow(c)
                    }
                    if appState.currentCommits.count > 8 {
                        Text(lang == .zh
                             ? "…还有 \(appState.currentCommits.count - 8) 个"
                             : "…and \(appState.currentCommits.count - 8) more")
                            .font(.piloSerifCaption)
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
            }
        } else if repo.uncommittedCount > 0 {
            Text(lang == .zh
                 ? "有 \(repo.uncommittedCount) 个改动还没 commit"
                 : "\(repo.uncommittedCount) change\(repo.uncommittedCount == 1 ? "" : "s") not committed yet")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .padding(.vertical, PiloSpacing.s)
        } else {
            Text(lang == .zh ? "都同步啦 ✨" : "All caught up ✨")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.mintSafe)
                .padding(.vertical, PiloSpacing.s)
        }
    }

    private func commitRow(_ c: CommitSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(c.hash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.piloGoldDark)
            Text(c.subject)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(RepoCard.relativeFormatter.localizedString(for: c.date, relativeTo: Date()))
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }

    private func actionsRow(for repo: Repository) -> some View {
        HStack(spacing: 8) {
            // 推送（primary mini）
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11))
                    Text(lang == .zh ? "推送" : "Push")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(MiniPrimaryButtonStyle())
            .disabled(repo.aheadCount == 0 || repo.currentBranch == nil)

            // 拉取（ghost）— 仅打开终端给用户跑 pull
            Button(lang == .zh ? "拉取" : "Pull") {
                openTerminal(at: repo.path)
            }
            .buttonStyle(MiniGhostButtonStyle())

            // 在终端打开（ghost）
            Button(lang == .zh ? "在终端打开" : "Open in Terminal") {
                openTerminal(at: repo.path)
            }
            .buttonStyle(MiniGhostButtonStyle())
        }
    }

    private func openTerminal(at path: String) {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private var emptyDetail: some View {
        VStack(spacing: PiloSpacing.l) {
            Spacer()
            PiloMascot(mood: .sleeping, size: 96, breathing: true)
            Text(lang == .zh ? "选一个仓库吧 ✨" : "Pick a repo ✨")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mini button styles（匹配 HTML 的 .btn-mini-primary / .btn-mini-ghost）

private struct MiniPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                (configuration.isPressed ? Color.piloBlueDark : Color.piloBlue)
                    .opacity(enabled ? 1 : 0.5)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct MiniGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(Color.inkSecondary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed
                          ? Color.cloudDivider.opacity(0.4)
                          : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cloudDivider, lineWidth: 0.5)
                    )
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
