import SwiftUI

struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            RepoListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let id = appState.selectedRepoId,
               let repo = appState.repositories.first(where: { $0.id == id }) {
                RepoDetailView(repo: repo)
            } else if let first = appState.sortedRepos.first {
                RepoDetailView(repo: first)
                    .onAppear { appState.selectedRepoId = first.id }
            } else {
                emptyDetail
            }
        }
        .navigationTitle("Pilo")
        .frame(minWidth: 680, minHeight: 420)
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            PiloMascot(mood: .sleeping, size: 80)
            Text(Copy.emptyNoRepos(appState.tone))
                .font(.piloBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
