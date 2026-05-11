import SwiftUI

/// Bear-vibe MenuBar popover：hero-centric 排版。
/// 上部 mascot + 标题占视觉重音；中部仓库列表极简；底部三工具 12pt 灰文字。
struct MenuBarView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding.rawValue) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, PiloSpacing.xl)
                .padding(.bottom, PiloSpacing.l)

            if appState.gitExecutablePath != nil && !appState.repositories.isEmpty && !appState.pendingRepos.isEmpty {
                divider
                    .padding(.vertical, PiloSpacing.s)
                pendingReposList
                    .padding(.bottom, PiloSpacing.m)
                divider
                    .padding(.vertical, PiloSpacing.s)
                primaryAction
                    .padding(.top, PiloSpacing.s)
                    .padding(.bottom, PiloSpacing.l)
            } else {
                Spacer(minLength: PiloSpacing.s)
            }

            footer
                .padding(.bottom, PiloSpacing.m)
        }
        .frame(width: 360)
        .padding(.horizontal, PiloSpacing.xl)
        .background(Color.creamBg)
        .task {
            if !hasCompletedOnboarding {
                openWindow(id: "onboarding")
            }
        }
    }

    // MARK: - Hero（mascot + 标题 + 副标题）

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: PiloSpacing.m) {
            PiloMascot(mood: heroMood, size: 88, breathing: true)
                .padding(.bottom, PiloSpacing.xs)
            Text(heroTitle)
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
                .tracking(-0.3)
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
        if appState.pendingRepos.isEmpty { return .sleeping }
        return .happy
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
            return "\(appState.killSwitchRemainingHours) 小时后自动恢复 · 点这里立即恢复"
        }
        if appState.gitExecutablePath == nil { return "在终端运行 xcode-select --install" }
        if !appState.isInitialScanComplete && appState.repositories.isEmpty { return "马上就好" }
        if appState.repositories.isEmpty { return "去设置里添加扫描目录吧" }
        if appState.pendingRepos.isEmpty { return Copy.menubarAllSynced(appState.tone).replacingOccurrences(of: "\n", with: " ") }
        return "\(appState.pendingRepos.count) 个仓库等着飞出去"
    }

    // MARK: - 仓库列表（极简 2 行 row）

    private var pendingReposList: some View {
        VStack(spacing: 0) {
            ForEach(Array(appState.pendingRepos.prefix(4))) { repo in
                pendingRepoRow(repo)
                if repo.id != appState.pendingRepos.prefix(4).last?.id {
                    divider.padding(.vertical, PiloSpacing.xs)
                }
            }
            if appState.pendingRepos.count > 4 {
                Text("…还有 \(appState.pendingRepos.count - 4) 个")
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.top, PiloSpacing.s)
            }
        }
    }

    private func pendingRepoRow(_ repo: Repository) -> some View {
        Button {
            appState.selectedRepoId = repo.id
            openWindow(id: "main")
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.piloSection)
                        .foregroundStyle(Color.inkPrimary)
                    Text(repoSubtitle(repo))
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
            }
            .padding(.vertical, PiloSpacing.s)
            .padding(.horizontal, PiloSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloBlue.opacity(0.06), cornerRadius: PiloRadius.small)
    }

    private func repoSubtitle(_ repo: Repository) -> String {
        var bits: [String] = []
        if repo.aheadCount > 0     { bits.append("↑ \(repo.aheadCount)") }
        if repo.behindCount > 0    { bits.append("↓ \(repo.behindCount)") }
        if repo.uncommittedCount > 0 { bits.append("\(repo.uncommittedCount) 待提交") }
        return bits.joined(separator: " · ")
    }

    // MARK: - 主 CTA（仅在 pending 有内容时显示）

    private var primaryAction: some View {
        Button {
            // 多 repo "push all" 留后续 phase；先打开主面板让用户挑
            openWindow(id: "main")
        } label: {
            Text(Copy.menubarPushAllButton)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.piloPrimary)
    }

    // MARK: - 底部三工具（最弱视觉权重）

    private var footer: some View {
        HStack(spacing: PiloSpacing.s) {
            Spacer()
            Button {
                openWindow(id: "main")
            } label: {
                Text(Copy.menubarOpenMainWindow)
            }
            .buttonStyle(.piloTextLink)

            Text("·").foregroundStyle(Color.inkTertiary)

            SettingsLink {
                Text(Copy.menubarSettings)
                    .font(.piloCaption)
                    .foregroundStyle(Color.piloBlue)
            }
            .buttonStyle(.plain)

            Text("·").foregroundStyle(Color.inkTertiary)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(Copy.menubarQuit)
            }
            .buttonStyle(.piloTextLink)
            .keyboardShortcut("q")
            Spacer()
        }
        .font(.piloCaption)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.inkPrimary.opacity(0.08))
            .frame(height: 1)
    }
}
