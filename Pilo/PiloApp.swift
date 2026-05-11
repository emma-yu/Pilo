import SwiftUI

@main
struct PiloApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        // 1. 菜单栏弹窗
        // 用 label-based MenuBarExtra 才能动态切换图标（Image asset / SF Symbol 混合）。
        // 正常状态：自定义鸽子 mascot；异常状态：SF Symbol（kill switch / 无 git）。
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .tone(appState.tone)
        } label: {
            menuBarLabel
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

    // 菜单栏图标 label：彩色 mascot 用于正常状态；异常态降级回 SF Symbol（更高辨识度）
    @ViewBuilder
    private var menuBarLabel: some View {
        if appState.isKillSwitchActive {
            Image(systemName: "eye.slash")
        } else if appState.gitExecutablePath == nil {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        } else {
            Image("MenuBarIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
    }
}
