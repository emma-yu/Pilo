import SwiftUI

@main
struct PiloApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        // 1. 菜单栏弹窗 — 用 SF Symbol（用户偏好：彩色 mascot 留给 Dock，菜单栏要轻量）
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
        .defaultSize(width: 560, height: 560)

        // 4. 设置（⌘+,）
        Settings {
            SettingsView()
                .environment(appState)
                .tone(appState.tone)
        }
    }

    // 菜单栏图标：用 SF Symbol，按状态切换；不会糊也省 menubar 空间
    private var menuBarSymbol: String {
        if appState.isKillSwitchActive { return "eye.slash" }
        if appState.gitExecutablePath == nil { return "exclamationmark.triangle" }
        let pending = appState.pendingRepos.count
        if pending == 0 { return "bird" }
        return "bird.fill"
    }
}
