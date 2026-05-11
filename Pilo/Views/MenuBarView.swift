import SwiftUI

struct MenuBarView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding.rawValue) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
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
            Button(Copy.menubarSettings) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        Divider()
            .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button(Copy.menubarOpenMainWindow) {
                openWindow(id: "main")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Spacer()

            Button(Copy.menubarSettings) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button(Copy.menubarQuit) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .keyboardShortcut("q")
        }
        .font(.piloCaption)
    }
}
