import SwiftUI

struct RepoListView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedRepoId },
            set: { appState.selectedRepoId = $0 }
        )) {
            Section {
                ForEach(appState.sortedRepos) { repo in
                    RepoCard(repo: repo, isSelected: repo.id == appState.selectedRepoId) {
                        appState.selectedRepoId = repo.id
                    }
                    .tag(repo.id as UUID?)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                }
            } header: {
                SectionHeader(title: "仓库", trailing: "\(appState.repositories.count)")
            }
        }
        .listStyle(.sidebar)
    }
}
