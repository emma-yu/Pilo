import SwiftUI

/// Bear-vibe 极简 sidebar：纸品色背景 + 大 label 顶 + 2 行 row。
/// 移除 chip / 蓝条 / dot。
struct RepoListView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // 纸品色 sidebar 背景，替代 SwiftUI 默认 .sidebar 灰
            Color.creamBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部签名感 label
                signatureHeader
                    .padding(.horizontal, PiloSpacing.l)
                    .padding(.top, PiloSpacing.xl)
                    .padding(.bottom, PiloSpacing.s)

                hairline
                    .padding(.horizontal, PiloSpacing.l)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(appState.sortedRepos) { repo in
                            RepoCard(repo: repo, isSelected: repo.id == appState.selectedRepoId) {
                                appState.selectedRepoId = repo.id
                            }
                            .padding(.horizontal, PiloSpacing.s)
                        }
                    }
                    .padding(.vertical, PiloSpacing.m)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var signatureHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PILO")
                .font(.piloLabel)
                .tracking(2.0)
                .foregroundStyle(Color.piloBlue)
            Text(headerSubtitle)
                .font(.piloCaption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        let total = appState.repositories.filter { !$0.isHidden }.count
        let pending = appState.pendingRepos.count
        if pending > 0 {
            return "\(total) 仓库 · 待处理 \(pending)"
        }
        return "\(total) 仓库都同步啦"
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.cloudDivider.opacity(0.6))
            .frame(height: 1)
    }
}
