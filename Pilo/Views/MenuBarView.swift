import SwiftUI

/// MenuBar popover v3.1：保留 hero + 仓库列表 + **完整 MenuActionRow footer**。
/// 移除 "一键推送全部"——push 走主面板单仓库 flow。
struct MenuBarView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding.rawValue) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if appState.isKillSwitchActive {
                killSwitchBanner
                    .padding(.horizontal, PiloSpacing.l)
                    .padding(.top, PiloSpacing.m)
            }

            hero
                .padding(.top, PiloSpacing.l)
                .padding(.bottom, PiloSpacing.m)

            content

            divider
                .padding(.vertical, PiloSpacing.s)

            footer
                .padding(.bottom, PiloSpacing.s)
        }
        .frame(width: 360)
        .padding(.horizontal, PiloSpacing.m)
        .background(Color.creamBg)
        .task {
            if !hasCompletedOnboarding {
                openWindow(id: "onboarding")
            }
        }
    }

    // MARK: - Kill switch banner

    private var killSwitchBanner: some View {
        Button {
            appState.deactivateKillSwitch()
        } label: {
            HStack(spacing: PiloSpacing.s) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(Color.amberWarn)
                Text(Copy.KillSwitch.bannerInMenuBar(appState.tone, remainingHours: appState.killSwitchRemainingHours))
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, PiloSpacing.m)
            .padding(.vertical, PiloSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: PiloRadius.small, style: .continuous)
                    .fill(Color.amberWarn.opacity(0.16))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero（真鸽子 + 标题 + 副标题）

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: PiloSpacing.s) {
            PiloMascot(mood: heroMood, size: 84, breathing: true)
                .padding(.bottom, PiloSpacing.xs)
            Text(heroTitle)
                .font(.piloTitle)
                .tracking(-0.3)
                .foregroundStyle(Color.inkPrimary)
            Text(heroSubtitle)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroMood: PiloMascot.Mood {
        if appState.isKillSwitchActive { return .sunglasses }
        if appState.gitExecutablePath == nil { return .worried }
        if !appState.isInitialScanComplete && appState.repositories.isEmpty { return .alert }
        if appState.repositories.isEmpty { return .sleeping }
        if appState.pendingRepos.isEmpty { return .happy }
        return .alert
    }

    private var heroTitle: String {
        if appState.isKillSwitchActive { return "安全检查暂停" }
        if appState.gitExecutablePath == nil { return "找不到 git" }
        if !appState.isInitialScanComplete && appState.repositories.isEmpty { return "正在找你的仓库" }
        if appState.repositories.isEmpty { return "咕咕～" }
        if appState.pendingRepos.isEmpty { return "都同步啦" }
        return "咕咕～"
    }

    private var heroSubtitle: String {
        if appState.isKillSwitchActive {
            return "\(appState.killSwitchRemainingHours) 小时后自动恢复"
        }
        if appState.gitExecutablePath == nil { return "在终端运行 xcode-select --install" }
        if !appState.isInitialScanComplete && appState.repositories.isEmpty { return "马上就好" }
        if appState.repositories.isEmpty { return "去设置里添加扫描目录吧" }
        if appState.pendingRepos.isEmpty { return "所有仓库都同步啦 ✨" }
        return "\(appState.pendingRepos.count) 个仓库等着飞出去"
    }

    // MARK: - Content（仓库列表）

    @ViewBuilder
    private var content: some View {
        if !appState.pendingRepos.isEmpty {
            VStack(spacing: 2) {
                ForEach(appState.pendingRepos.prefix(4)) { repo in
                    pendingRepoRow(repo)
                }
                if appState.pendingRepos.count > 4 {
                    Text("…还有 \(appState.pendingRepos.count - 4) 个")
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.top, PiloSpacing.xs)
                }
            }
            .padding(.horizontal, PiloSpacing.xs)
        }
    }

    private func pendingRepoRow(_ repo: Repository) -> some View {
        Button {
            appState.selectedRepoId = repo.id
            openWindow(id: "main")
        } label: {
            HStack(spacing: PiloSpacing.s) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(.piloSection)
                        .foregroundStyle(Color.inkPrimary)
                    Text(repoSubtitle(repo))
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.vertical, PiloSpacing.s)
            .padding(.horizontal, PiloSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloBlue.opacity(0.08), cornerRadius: PiloRadius.small)
    }

    private func repoSubtitle(_ repo: Repository) -> String {
        var bits: [String] = []
        if repo.aheadCount > 0      { bits.append("↑ \(repo.aheadCount)") }
        if repo.behindCount > 0     { bits.append("↓ \(repo.behindCount)") }
        if repo.uncommittedCount > 0 { bits.append("\(repo.uncommittedCount) 待提交") }
        return bits.joined(separator: " · ")
    }

    // MARK: - Footer (Phase 2 style — 三行 MenuActionRow，已去除一键推送)

    private var footer: some View {
        VStack(spacing: 0) {
            MenuActionRow(
                icon: "macwindow",
                title: Copy.menubarOpenMainWindow,
                shortcut: "⌘↑",
                action: { openWindow(id: "main") }
            )
            MenuActionRowWithSettingsLink(
                icon: "gearshape",
                title: Copy.menubarSettings,
                shortcut: "⌘,"
            )
            MenuActionRow(
                icon: "power",
                title: Copy.menubarQuit,
                shortcut: "⌘Q",
                isDestructive: true,
                action: { NSApplication.shared.terminate(nil) }
            )
            .keyboardShortcut("q")
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.inkPrimary.opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - Menu action row

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let shortcut: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PiloSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)
                    .foregroundStyle(isDestructive ? Color.roseDanger : Color.piloBlue)
                Text(title)
                    .font(.piloBody)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            .padding(.horizontal, PiloSpacing.s)
            .padding(.vertical, PiloSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(
            highlight: (isDestructive ? Color.roseDanger : Color.piloBlue).opacity(0.10),
            cornerRadius: PiloRadius.small
        )
    }
}

private struct MenuActionRowWithSettingsLink: View {
    let icon: String
    let title: String
    let shortcut: String

    var body: some View {
        SettingsLink {
            HStack(spacing: PiloSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)
                    .foregroundStyle(Color.piloBlue)
                Text(title)
                    .font(.piloBody)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(shortcut)
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, PiloSpacing.s)
            .padding(.vertical, PiloSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloBlue.opacity(0.10), cornerRadius: PiloRadius.small)
    }
}
