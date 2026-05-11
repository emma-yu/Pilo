import SwiftUI

struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            RepoListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            ZStack {
                // 顶部双层柔渐变："日出"感——PiloBlue 6% + PiloCream 4%
                LinearGradient(
                    colors: [Color.piloBlue.opacity(0.06), Color.piloCream.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                Group {
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
            }
        }
        .navigationTitle("Pilo")
        .frame(minWidth: 760, minHeight: 500)
    }

    private var emptyDetail: some View {
        PiloHero(
            mood: .sleeping,
            title: "还没有发现仓库",
            subtitle: Copy.emptyNoRepos(appState.tone),
            mascotSize: 104,
            decorations: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
