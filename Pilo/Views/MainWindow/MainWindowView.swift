import SwiftUI

struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            RepoListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            ZStack {
                // Bear-vibe：纯纸品色底，无渐变，靠留白和文字呼吸
                Color.creamBg
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
        .frame(minWidth: 920, minHeight: 540)
    }

    private var emptyDetail: some View {
        VStack(spacing: PiloSpacing.xl) {
            Spacer()
            PiloMascot(mood: .sleeping, size: 140, breathing: true)
            VStack(spacing: PiloSpacing.s) {
                Text("还没有发现仓库")
                    .font(.piloHero)
                    .tracking(-0.5)
                    .foregroundStyle(Color.inkPrimary)
                Text(Copy.emptyNoRepos(appState.tone))
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
