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
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .listRowBackground(Color.clear)   // 让 RepoCard 自己的 hover/selected 背景接管
                }
            } header: {
                SectionHeader(title: "仓库", trailing: "\(appState.repositories.count)")
                    .padding(.bottom, 4)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}
