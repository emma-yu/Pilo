import SwiftUI

@main
struct PiloApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        // 1. 菜单栏弹窗
        MenuBarExtra("Pilo", systemImage: menuBarSymbol) {
            MenuBarView()
                .environment(appState)
                .tone(appState.tone)
        }
        .menuBarExtraStyle(.window)

        // 2. 主窗口（默认隐藏，用户从菜单栏唤起）
        Window("Pilo", id: "main") {
            MainWindowView()
                .environment(appState)
                .tone(appState.tone)
                .background(Color.creamBg)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 760, height: 480)

        // 3. Onboarding 4 屏（首次启动）
        Window("Onboarding", id: "onboarding") {
            OnboardingFlow()
                .environment(appState)
                .tone(appState.tone)
                .background(Color.creamBg)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 440)

        // 4. 设置（⌘+,）
        Settings {
            SettingsView()
                .environment(appState)
                .tone(appState.tone)
        }
    }

    // 菜单栏图标：根据状态切换；用 SF Symbol 18×18 大小，避免在带刘海的外接显示器上裁切
    private var menuBarSymbol: String {
        if appState.isKillSwitchActive { return "eye.slash" }     // 安全检查暂停
        let pending = appState.pendingRepos.count
        if appState.gitExecutablePath == nil { return "exclamationmark.bird" }
        if pending == 0 { return "bird" }
        return "bird.fill"
    }
}
