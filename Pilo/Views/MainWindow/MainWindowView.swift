import SwiftUI

/// v3.5 主窗口 = 面板。无外层标题、无内嵌卡片——窗口内容直接是 PanelHeader + 2 栏。
struct MainWindowView: View {

    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        Group {
            if appState.repositories.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.paperCard)
            } else {
                MainPanel()
            }
        }
        // PushConfirmDialog sheet 已移到 MainPanel 内部，跟 Markdown 预览 sheet 一起 attach。
        // 这里只保留窗口级别的 navigationTitle + 默认选 repo。
        .navigationTitle(lang == .zh ? "Pilo · 我的小邮局" : "Pilo · My Post Office")
        .frame(minWidth: 880, minHeight: 580)
        .onAppear {
            if appState.selectedRepoId == nil,
               let first = appState.activeRepos.first ?? appState.sortedRepos.first {
                appState.selectRepo(first.id)
            }
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
    }
}
