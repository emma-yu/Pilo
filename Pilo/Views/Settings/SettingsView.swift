import SwiftUI

/// v3.7 邮局风 Settings：每个 tab 顶部加 SettingsTabHeader（衬线 + 斜体宋体 + 金色 hairline）；
/// scan / hidden 行用 cream paper card；about 已在 v3.3 做过。
struct SettingsView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(lang == .zh ? "通用" : "General", systemImage: "gearshape") }
            scanTab
                .tabItem { Label(lang == .zh ? "扫描" : "Scan", systemImage: "folder") }
            securityTab
                .tabItem { Label(lang == .zh ? "安全" : "Security", systemImage: "shield") }
            hiddenReposTab
                .tabItem { Label(lang == .zh ? "已隐藏" : "Hidden", systemImage: "eye.slash") }
                .badge(appState.hiddenRepos.count)
            aboutTab
                .tabItem { Label(lang == .zh ? "关于" : "About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 540)
        .background(Color.creamBg)
    }

    private var lang: Language { appState.language }

    // MARK: - 通用

    private var generalTab: some View {
        VStack(spacing: 0) {
            SettingsTabHeader(
                zhTitle: "通用 · General",
                enTitle: "General · 通用",
                zhSubtitle: "— 调整 Pilo 的语言和语气 —",
                enSubtitle: "— tune Pilo's language and tone —"
            )

            Form {
                Section {
                    Picker("", selection: Binding(
                        get: { appState.language },
                        set: { appState.updateLanguage($0) }
                    )) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.nativeName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(lang == .zh
                        ? "界面文字会立即切换；初次启动时按系统语言推断"
                        : "UI text switches immediately; defaults to your system language on first launch")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(.secondary)
                } header: {
                    sectionLabel(lang == .zh ? "语言 / Language" : "Language / 语言")
                }

                Section {
                    Picker("", selection: Binding(
                        get: { appState.tone },
                        set: { appState.updateTone($0) }
                    )) {
                        ForEach(Tone.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(lang == .zh
                        ? "Friendly 模式带温柔可爱语气（「咕咕～」），Minimal 模式信息密度优先"
                        : "Friendly mode uses warm playful tone (\"Coo coo~\"). Minimal mode prioritises density.")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(.secondary)
                } header: {
                    sectionLabel(lang == .zh ? "语调 / Tone" : "Tone / 语调")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color.creamBg)
    }

    // MARK: - 扫描

    private var scanTab: some View {
        VStack(spacing: 0) {
            SettingsTabHeader(
                zhTitle: "扫描 · Scan",
                enTitle: "Scan · 扫描",
                zhSubtitle: "— 告诉 Pilo 去哪里找你的代码 —",
                enSubtitle: "— tell Pilo where to look for your code —"
            )

            Form {
                Section {
                    if appState.watchDirectories.isEmpty {
                        Text(lang == .zh ? "还没有添加任何目录" : "No folders added yet")
                            .font(.piloSerifSubtitle)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.watchDirectories, id: \.self) { url in
                            watchDirRow(url: url)
                        }
                    }

                    Button(action: addDirectory) {
                        Label(lang == .zh ? "添加目录" : "Add folder", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.piloBlue)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                } header: {
                    sectionLabel(lang == .zh ? "扫描目录" : "Watch folders")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color.creamBg)
    }

    private func watchDirRow(url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(lang == .zh ? "移除" : "Remove") {
                appState.removeWatchDirectory(url)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(Color.roseDanger)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = lang == .zh ? "选择 Pilo 要扫描的根目录" : "Pick a root folder for Pilo to scan"
        if panel.runModal() == .OK, let url = panel.url {
            appState.addWatchDirectory(url)
        }
    }

    // MARK: - 安全（Phase 6）

    private var securityTab: some View {
        VStack(spacing: 0) {
            SettingsTabHeader(
                zhTitle: "安全 · Security",
                enTitle: "Security · 安全",
                zhSubtitle: "— Pilo 在 push 前帮你查的东西 —",
                enSubtitle: "— what Pilo checks before each push —"
            )

            Form {
                Section {
                    Text(Copy.KillSwitch.settingsToggleDescription)
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                } header: {
                    sectionLabel(lang == .zh ? "敏感信息扫描" : "Secret scanner")
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
                                    .font(.piloSerifSubtitle)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if appState.isKillSwitchActive {
                            HStack(spacing: 10) {
                                Text(String(format: Copy.KillSwitch.settingsKillSwitchActiveLabel,
                                            appState.killSwitchRemainingHours))
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
                } header: {
                    sectionLabel(lang == .zh ? "紧急关闭" : "Emergency off")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Color.creamBg)
    }

    // MARK: - 已隐藏

    private var hiddenReposTab: some View {
        VStack(spacing: 0) {
            SettingsTabHeader(
                zhTitle: "已隐藏 · Hidden",
                enTitle: "Hidden · 已隐藏",
                zhSubtitle: "— 偷偷藏起来不打扰你的仓库 —",
                enSubtitle: "— repos quietly tucked away —"
            )

            if appState.hiddenRepos.isEmpty {
                emptyHiddenState
            } else {
                Form {
                    Section {
                        ForEach(appState.hiddenRepos) { repo in
                            hiddenRepoRow(repo)
                        }
                    } header: {
                        sectionLabel(lang == .zh ? "已隐藏的仓库" : "Hidden repos")
                    }

                    Section {
                        Text(lang == .zh
                            ? "隐藏的仓库不会出现在菜单栏 popover 和主面板里，但 Pilo 仍然会扫描它们以便随时恢复。"
                            : "Hidden repos won't appear in the menu bar popover or main panel, but Pilo still scans them so you can restore anytime.")
                            .font(.piloSerifSubtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.creamBg)
    }

    private var emptyHiddenState: some View {
        VStack(spacing: PiloSpacing.m) {
            Spacer(minLength: PiloSpacing.xxxl)
            PiloMascot(mood: .sleeping, size: 70, breathing: true)
            Text(lang == .zh ? "什么都没藏" : "Nothing tucked away")
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
            Text(lang == .zh
                 ? "在主面板右键任意仓库 → 「隐藏此仓库」"
                 : "Right-click any repo in the main panel → \"Hide this repo\"")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hiddenRepoRow(_ repo: Repository) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.piloSection)
                Text(repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(lang == .zh ? "恢复" : "Restore") {
                appState.setHidden(false, repoId: repo.id)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(Color.piloBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }

    // MARK: - 关于

    private var aboutTab: some View {
        ZStack {
            Color.piloCream.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: PiloSpacing.l) {
                OrnamentDivider(width: 220)
                    .padding(.top, PiloSpacing.s)

                ZStack(alignment: .topTrailing) {
                    PiloMascot(mood: .happy, size: 110, breathing: true)
                    WaxSeal(size: 40)
                        .offset(x: 8, y: -2)
                }

                VStack(spacing: PiloSpacing.s) {
                    Text(lang == .zh ? "Pilo 邮局" : "Pilo Post Office")
                        .font(.piloSerifHero)
                        .tracking(1.0)
                        .foregroundStyle(Color.inkPrimary)
                    Text(lang == .zh ? "— 一只帮你安全送代码的小信鸽 —"
                                      : "— a little pigeon delivering your code —")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkSecondary)
                    HandDrawnUnderline(width: 60, color: .piloAccent)
                    Text("v0.1.0 · MIT License")
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                    Text("Made with 🕊️ by Emma")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkSecondary)
                }

                if let v = appState.gitVersion, let p = appState.gitExecutablePath {
                    Divider().padding(.horizontal, PiloSpacing.xxl)
                    VStack(spacing: PiloSpacing.xs) {
                        Text(lang == .zh ? "找到 \(v)" : "Found \(v)")
                            .font(.piloSerifCaption)
                            .foregroundStyle(Color.inkSecondary)
                        Text(p)
                            .font(.piloMono)
                            .foregroundStyle(Color.inkSecondary)
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(PiloSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 共享 section label（斜体宋体）

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.piloSerifLabel)
            .tracking(1.0)
            .foregroundStyle(Color.piloGoldDark)
    }
}
