import SwiftUI

struct RepoListView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 chip 替代传统标题——更现代、信息密度更高
            sidebarHeaderChip
                .padding(.horizontal, PiloSpacing.m)
                .padding(.top, PiloSpacing.m)
                .padding(.bottom, PiloSpacing.s)

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
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    SectionHeader(title: "仓库", style: .label)
                        .padding(.bottom, PiloSpacing.xs)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    private var sidebarHeaderChip: some View {
        let total = appState.repositories.filter { !$0.isHidden }.count
        let pending = appState.pendingRepos.count
        let text: String
        if pending > 0 {
            text = "\(total) 仓库 · \(pending) 待推送"
        } else {
            text = "\(total) 仓库"
        }
        return HStack {
            PiloChip(
                icon: "shippingbox.fill",
                text: text,
                tint: .piloBlue,
                style: .tinted,
                size: .medium
            )
            Spacer()
        }
    }
}
