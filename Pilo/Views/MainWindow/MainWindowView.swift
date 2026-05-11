import SwiftUI

/// v3.4 主窗口：彻底放弃 NavigationSplitView，按 HTML 参考 scene 2 复刻——
/// 整个窗口背景 cream + 顶部「Pilo · 产品 Demo」衬线标题 + 居中 MainPanel 卡片。
struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        ZStack {
            // 整窗 cream 底色（HTML body bg #F5F2EC）
            Color.creamBg
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: PiloSpacing.l) {
                    // 顶部页面标题（衬线居中 + 斜体副标题）
                    pageHeader
                        .padding(.top, PiloSpacing.xl)
                        .padding(.bottom, PiloSpacing.s)

                    if appState.repositories.isEmpty {
                        emptyState
                            .padding(.top, PiloSpacing.xxxl)
                    } else {
                        MainPanel()
                            .padding(.horizontal, PiloSpacing.xl)
                            .padding(.bottom, PiloSpacing.xl)
                    }
                }
            }
            .sheet(item: Binding(
                get: { appState.pushSession },
                set: { appState.pushSession = $0 }
            )) { _ in
                PushConfirmDialog(
                    session: Binding(
                        get: { appState.pushSession },
                        set: { appState.pushSession = $0 }
                    ),
                    onDismiss: { appState.dismissPushSession() }
                )
            }
        }
        .navigationTitle("Pilo")
        .frame(minWidth: 800, minHeight: 580)
        // 默认选中第一个 repo（lazy 加载 commits）
        .onAppear {
            if appState.selectedRepoId == nil,
               let first = appState.activeRepos.first ?? appState.sortedRepos.first {
                appState.selectRepo(first.id)
            }
        }
    }

    private var pageHeader: some View {
        VStack(spacing: 2) {
            Text(lang == .zh ? "Pilo · 我的小邮局" : "Pilo · My Post Office")
                .font(.piloSerifTitle)
                .tracking(1.0)
                .foregroundStyle(Color.inkPrimary)
            Text(lang == .zh ? "— 一只帮你安全送出代码的小信鸽 —"
                              : "— a little pigeon delivering your code —")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: PiloSpacing.l) {
            OrnamentDivider(width: 220)
            PiloMascot(mood: .sleeping, size: 140, breathing: true)
            Text(lang == .zh ? "还没有发现仓库" : "No repos yet")
                .font(.piloSerifHero)
                .foregroundStyle(Color.inkPrimary)
            Text(Copy.emptyNoRepos(appState.tone, lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
        .padding(PiloSpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}
