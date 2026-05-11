import SwiftUI

struct SettingsView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            scanTab
                .tabItem { Label("扫描", systemImage: "folder") }
            hiddenReposTab
                .tabItem { Label("已隐藏", systemImage: "eye.slash") }
                .badge(appState.hiddenRepos.count)
            aboutTab
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 460)
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
        VStack(spacing: 14) {
            PiloMascot(mood: .happy, size: 72)
            Text("Pilo")
                .font(.piloTitle)
            Text("v0.1.0 · MIT License")
                .font(.piloCaption)
                .foregroundStyle(.secondary)
            Text("Made with 🕊️ by Emma")
                .font(.piloBody)
                .foregroundStyle(.secondary)
            if let v = appState.gitVersion, let p = appState.gitExecutablePath {
                Divider().padding(.vertical, 8)
                Text("找到 \(v)")
                    .font(.piloCaption)
                    .foregroundStyle(.secondary)
                Text(p)
                    .font(.piloMono)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
