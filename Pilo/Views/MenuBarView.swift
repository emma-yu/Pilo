import SwiftUI

struct MenuBarView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding.rawValue) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if appState.isKillSwitchActive {
                killSwitchBanner
            }
            content
            divider
            footer
        }
        .frame(width: 360)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .task {
            if !hasCompletedOnboarding {
                openWindow(id: "onboarding")
            }
        }
    }

    private var killSwitchBanner: some View {
        Button {
            appState.deactivateKillSwitch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(Color.amberWarn)
                Text(Copy.KillSwitch.bannerInMenuBar(appState.tone, remainingHours: appState.killSwitchRemainingHours))
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.amberWarn.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appState.gitExecutablePath == nil {
            gitNotFoundState
        } else if !appState.isInitialScanComplete && appState.repositories.isEmpty {
            scanningState
        } else if appState.repositories.isEmpty {
            emptyReposState
        } else if appState.pendingRepos.isEmpty {
            allSyncedState
        } else {
            pendingReposList
        }
    }

    private var gitNotFoundState: some View {
        VStack(spacing: 12) {
            PiloMascot(mood: .worried, size: 56)
            Text(Copy.gitNotFound(appState.tone))
                .font(.piloBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var scanningState: some View {
        VStack(spacing: 12) {
            PiloMascot(mood: .alert, size: 56)
            Text(appState.scanProgressMessage ?? Copy.menubarScanInProgress(appState.tone))
                .font(.piloBody)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var emptyReposState: some View {
        VStack(spacing: 12) {
            PiloMascot(mood: .sleeping, size: 56)
            Text(Copy.emptyNoRepos(appState.tone))
                .font(.piloBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsLink {
                Text(Copy.menubarSettings)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    private var allSyncedState: some View {
        VStack(spacing: 10) {
            PiloMascot(mood: .sleeping, size: 56)
            Text(Copy.menubarAllSynced(appState.tone))
                .font(.piloBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("menubar.allSynced")
    }

    private var pendingReposList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.menubarPendingHeader(appState.tone, count: appState.pendingRepos.count))
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
                .padding(.bottom, 4)

            ForEach(appState.pendingRepos) { repo in
                RepoCard(repo: repo, isSelected: false) {
                    appState.selectedRepoId = repo.id
                    openWindow(id: "main")
                }
            }
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.inkPrimary.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, PiloSpacing.s)
            .padding(.horizontal, PiloSpacing.xs)
    }

    // MARK: - Footer (重设计：全宽 row 替代挤压的 HStack)

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
}

// MARK: - Menu action row（全宽可点 + hover bg + icon + 快捷键 hint）

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
                    .font(.system(size: 13, weight: .medium))
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
            highlight: (isDestructive ? Color.roseDanger : Color.accentColor).opacity(0.12),
            cornerRadius: PiloRadius.small
        )
    }
}

/// macOS Settings scene 必须用 SettingsLink，不能用 Button + openWindow，
/// 所以单独写一个支持 hover 的 SettingsLink 容器。
private struct MenuActionRowWithSettingsLink: View {
    let icon: String
    let title: String
    let shortcut: String

    var body: some View {
        SettingsLink {
            HStack(spacing: PiloSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
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
        .hoverable(highlight: Color.accentColor.opacity(0.12), cornerRadius: PiloRadius.small)
    }
}
