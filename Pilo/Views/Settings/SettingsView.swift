import SwiftUI

struct SettingsView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            scanTab
                .tabItem { Label("扫描", systemImage: "folder") }
            securityTab
                .tabItem { Label("安全", systemImage: "shield") }
            hiddenReposTab
                .tabItem { Label("已隐藏", systemImage: "eye.slash") }
                .badge(appState.hiddenRepos.count)
            aboutTab
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - 安全（Phase 6）

    private var securityTab: some View {
        Form {
            Section(Copy.KillSwitch.settingsSectionTitle) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.KillSwitch.settingsToggleDescription)
                        .font(.piloCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: appState.isKillSwitchActive ? "eye.slash.fill" : "shield.fill")
                            .foregroundStyle(appState.isKillSwitchActive ? Color.amberWarn : Color.mintSafe)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Copy.KillSwitch.settingsKillSwitchTitle)
                                .font(.piloSection)
                            Text(Copy.KillSwitch.settingsKillSwitchDesc)
                                .font(.piloCaption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if appState.isKillSwitchActive {
                        HStack(spacing: 10) {
                            Text(String(format: Copy.KillSwitch.settingsKillSwitchActiveLabel, appState.killSwitchRemainingHours))
                                .font(.piloBody)
                                .foregroundStyle(Color.amberWarn)
                            Spacer()
                            Button(Copy.KillSwitch.settingsKillSwitchRestoreButton) {
                                appState.deactivateKillSwitch()
                            }
                            .buttonStyle(.piloPrimary)
                        }
                        .padding(.top, 6)
                    } else {
                        HStack {
                            Spacer()
                            Button(Copy.KillSwitch.settingsKillSwitchActivateButton) {
                                appState.activateKillSwitch()
                            }
                            .buttonStyle(.piloSecondary)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 已隐藏

    private var hiddenReposTab: some View {
        Form {
            Section("已隐藏的仓库") {
                if appState.hiddenRepos.isEmpty {
                    Text("没有隐藏的仓库。\n在主面板右键任意仓库 → 「隐藏此仓库」。")
                        .font(.piloCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    ForEach(appState.hiddenRepos) { repo in
                        HStack(spacing: 10) {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(Color.inkTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name)
                                    .font(.piloSection)
                                Text(repo.path)
                                    .font(.piloMono)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("恢复") {
                                appState.setHidden(false, repoId: repo.id)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section {
                Text("隐藏的仓库不会出现在菜单栏 popover 和主面板里，但 Pilo 仍然会扫描它们以便随时恢复。")
                    .font(.piloCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 通用

    private var generalTab: some View {
        Form {
            Section("语调") {
                Picker("语调", selection: Binding(
                    get: { appState.tone },
                    set: { appState.updateTone($0) }
                )) {
                    ForEach(Tone.allCases, id: \.self) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Text("Friendly 模式带温柔语气，Minimal 模式信息密度优先")
                    .font(.piloCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 扫描

    private var scanTab: some View {
        Form {
            Section("扫描目录") {
                if appState.watchDirectories.isEmpty {
                    Text("还没有添加任何目录")
                        .font(.piloCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.watchDirectories, id: \.self) { url in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(Color.piloBlue)
                            Text(url.path)
                                .font(.piloMono)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("移除") {
                                appState.removeWatchDirectory(url)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }

                Button("+ 添加目录") {
                    addDirectory()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Pilo 要扫描的根目录"
        if panel.runModal() == .OK, let url = panel.url {
            appState.addWatchDirectory(url)
        }
    }

    // MARK: - 关于

    private var aboutTab: some View {
        ZStack {
            // 温暖奶油 surface 区别于其它 tab 的中性灰
            Color.piloCream.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                PiloMascot(mood: .happy, size: 88, breathing: true)
                Text("Pilo")
                    .font(.piloTitle)
                Text("v0.1.0 · MIT License")
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkSecondary)
                Text("Made with 🕊️ by Emma")
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
                if let v = appState.gitVersion, let p = appState.gitExecutablePath {
                    Divider().padding(.vertical, 8).padding(.horizontal, 40)
                    Text("找到 \(v)")
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                    Text(p)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
