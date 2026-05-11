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
        HStack(spacing: 12) {
            // 金色 5 角星图标
            Image(systemName: "star.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.piloGold)

            Text(lang == .zh ? "Pilo · 我的小邮局" : "Pilo · My Post Office")
                .font(.piloSerifTitle)
                .foregroundStyle(Color.inkPrimary)
                .tracking(0.5)

            Spacer()

            healthPill
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("CreamBg").opacity(0.35))
    }

    private var healthPill: some View {
        let healthy = appState.gitExecutablePath != nil
        let text = healthy
            ? (lang == .zh ? "SSH · Token · 一切都好" : "SSH · Token · All good")
            : (lang == .zh ? "未找到 git" : "git missing")
        let tint: Color = healthy ? .stampMint : .roseDanger

        return HStack(spacing: 5) {
            Image(systemName: healthy ? "checkmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
            .font(.piloSerifSubtitle)
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 18)
    }

    private func sidebarItem(_ repo: Repository) -> some View {
        let isActive = repo.id == appState.selectedRepoId
        return Button {
            appState.selectRepo(repo.id)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor(for: repo))
                    .frame(width: 9, height: 9)
                Text(repo.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if let count = countLabel(for: repo) {
                    Text(count)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.piloBlue)
                }
            }
            .padding(.horizontal, isActive ? 16 : 18)
            .padding(.vertical, 11)
            .background(
                isActive
                    ? Color.piloBlue.opacity(0.12)
                    : Color.clear
            )
            .overlay(alignment: .leading) {
                if isActive {
                    Rectangle()
                        .fill(Color.piloBlue)
                        .frame(width: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: isActive ? .clear : Color.piloBlue.opacity(0.06))
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
                    // 标题行：repo 名 + 右上 PrivacyPill
                    HStack(alignment: .firstTextBaseline) {
                        Text(repo.name)
                            .font(.piloSerifHero)
                            .tracking(0.5)
                            .foregroundStyle(Color.inkPrimary)
                        Spacer(minLength: 12)
                        PrivacyPill(isPublic: repo.remotes.first?.isPublic)
                    }

                    // mono 路径 + 分支（按 mock 去掉时间）
                    Text(metaLine(for: repo))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.top, 8)

                    // 状态药丸（ahead / uncommitted / synced 三态）
                    RepoStatusPill(repo: repo)
                        .padding(.top, 18)

                    // 三态 body：ahead → 信件列表；uncommitted → 玫粉单卡；synced → 居中睡 Pilo
                    bodyContent(for: repo)

                    Spacer(minLength: 24)

                    actionsRow(for: repo)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            emptyDetail
        }
    }

    // MARK: - Three-state body

    @ViewBuilder
    private func bodyContent(for repo: Repository) -> some View {
        if repo.aheadCount > 0 {
            // 状态 1：有待推 commit
            SectionDivider(label: lang == .zh ? "— 待寄出的小信 —" : "— letters to send —")
                .padding(.top, 26)
                .padding(.bottom, 12)
            commitsList(for: repo)
        } else if repo.uncommittedCount > 0 {
            // 状态 2：只有未提交
            SectionDivider(label: lang == .zh ? "— 等待 commit 的草稿 —" : "— drafts waiting to commit —")
                .padding(.top, 26)
                .padding(.bottom, 12)
            uncommittedCard(for: repo)
        } else {
            // 状态 3：已同步——居中睡 Pilo
            syncedEmptyState
                .padding(.top, 40)
        }
    }

    private func uncommittedCard(for repo: Repository) -> some View {
        let text = lang == .zh
            ? "有 \(repo.uncommittedCount) 个未提交的修改 · 请在编辑器里 commit 后再回来推送"
            : "\(repo.uncommittedCount) uncommitted change\(repo.uncommittedCount == 1 ? "" : "s") · commit them in your editor, then come back to push"
        return Text(text)
            .font(.piloSerifSubtitle)
            .foregroundStyle(Color.roseDanger.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.roseDanger.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.roseDanger.opacity(0.25), lineWidth: 0.5)
            )
    }

    private var syncedEmptyState: some View {
        VStack(spacing: PiloSpacing.s) {
            PiloMascot(mood: .sleeping, size: 80, breathing: true)
            Text(lang == .zh ? "这个仓库一切都好" : "All good here")
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
            Text(lang == .zh ? "没什么要寄出的" : "nothing to send")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentRepo: Repository? {
        guard let id = appState.selectedRepoId else {
            // 默认选第一个 active
            return appState.activeRepos.first ?? appState.sortedRepos.first
        }
        return appState.repositories.first(where: { $0.id == id })
    }

    private func metaLine(for repo: Repository) -> String {
        // 按设计稿：只显示 path · branch，时间挪到 commit 卡片或省略
        var parts: [String] = [repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
        if let b = repo.currentBranch { parts.append(b) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func commitsList(for repo: Repository) -> some View {
        if appState.currentCommits.isEmpty {
            Text(lang == .zh ? "正在拉取 commit..." : "Loading commits...")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkTertiary)
                .padding(.vertical, PiloSpacing.s)
        } else {
            VStack(spacing: 8) {
                ForEach(appState.currentCommits.prefix(8)) { c in
                    commitRow(c)
                }
                if appState.currentCommits.count > 8 {
                    Text(lang == .zh
                         ? "…还有 \(appState.currentCommits.count - 8) 个"
                         : "…and \(appState.currentCommits.count - 8) more")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
    }

    private func commitRow(_ c: CommitSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(c.hash)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.piloGoldDark)
            Text(c.subject)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(RepoCard.relativeFormatter.localizedString(for: c.date, relativeTo: Date()))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }

    private func actionsRow(for repo: Repository) -> some View {
        HStack(spacing: 10) {
            // 推送（primary）
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                    Text(lang == .zh ? "推送" : "Push")
                }
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(MiniPrimaryButtonStyle())
            .disabled(repo.aheadCount == 0 || repo.currentBranch == nil)

            // 拉取（ghost）
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
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                (configuration.isPressed ? Color.piloBlueDark : Color.piloBlue)
                    .opacity(enabled ? 1 : 0.5)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct MiniGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(Color.inkSecondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(configuration.isPressed
                          ? Color.cloudDivider.opacity(0.4)
                          : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.cloudDivider, lineWidth: 0.5)
                    )
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
