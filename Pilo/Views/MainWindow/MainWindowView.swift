import SwiftUI

struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            RepoListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            ZStack {
                // 顶部柔渐变：PiloBlue 4% → 透明，让主区域有"天空感"但不干扰内容
                LinearGradient(
                    colors: [Color.piloBlue.opacity(0.06), Color.clear],
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
        .frame(minWidth: 720, minHeight: 460)
    }

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            PiloMascot(mood: .sleeping, size: 96, breathing: true)
            Text(Copy.emptyNoRepos(appState.tone))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
