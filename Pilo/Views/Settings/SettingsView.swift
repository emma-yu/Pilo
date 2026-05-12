import SwiftUI

/// v3.7 邮局风 Settings：每个 tab 顶部加 SettingsTabHeader（衬线 + 斜体宋体 + 金色 hairline）；
/// scan / hidden 行用 cream paper card；about 已在 v3.3 做过。
struct SettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var pasteText: String = ""
    @State private var pasteError: String? = nil

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

            ScrollView {
                VStack(alignment: .leading, spacing: PiloSpacing.xl) {
                    // 语言区
                    VStack(alignment: .leading, spacing: PiloSpacing.s) {
                        sectionLabel(lang == .zh ? "语言 / Language" : "Language / 语言")
                        LanguageCardPicker(
                            selection: Binding(
                                get: { appState.language },
                                set: { _ in }
                            ),
                            onChange: { newLang in appState.updateLanguage(newLang) }
                        )
                        Text(lang == .zh
                            ? "界面文字会立即切换；初次启动时按系统语言推断"
                            : "UI text switches immediately; defaults to your system language on first launch")
                            .font(.piloSerifSubtitle)
                            .foregroundStyle(Color.inkSecondary)
                    }

                    // 语调区
                    VStack(alignment: .leading, spacing: PiloSpacing.s) {
                        sectionLabel(lang == .zh ? "语调 / Tone" : "Tone / 语调")
                        ToneCardPicker(
                            selection: Binding(
                                get: { appState.tone },
                                set: { _ in }
                            ),
                            onChange: { newTone in appState.updateTone(newTone) }
                        )
                        Text(lang == .zh
                            ? "Friendly 模式带温柔可爱语气（「咕咕～」），Minimal 模式信息密度优先"
                            : "Friendly: warm playful tone (\"Coo coo~\"). Minimal: terse and dense.")
                            .font(.piloSerifSubtitle)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .padding(PiloSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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

            ScrollView {
                VStack(alignment: .leading, spacing: PiloSpacing.m) {
                    sectionLabel(lang == .zh ? "扫描目录" : "Watch folders")

                    if appState.watchDirectories.isEmpty {
                        Text(lang == .zh ? "还没有添加任何目录" : "No folders added yet")
                            .font(.piloSerifSubtitle)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.vertical, PiloSpacing.s)
                    } else {
                        ForEach(appState.watchDirectories, id: \.self) { url in
                            watchDirRow(url: url)
                        }
                    }

                    PiloAddRowButton(
                        title: lang == .zh ? "添加目录" : "Add folder",
                        action: addDirectory
                    )
                    .padding(.top, PiloSpacing.xs)

                    pasteDirectoryRow
                        .padding(.top, PiloSpacing.xs)
                }
                .padding(PiloSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.creamBg)
    }

    private var pasteDirectoryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.piloGold.opacity(0.35))
                    .frame(height: 0.5)
                Text(lang == .zh ? "或直接粘贴路径" : "or paste a path")
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.piloGoldDark)
                    .fixedSize()
                Rectangle()
                    .fill(Color.piloGold.opacity(0.35))
                    .frame(height: 0.5)
            }
            .padding(.vertical, 2)

            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.piloGoldDark)
                TextField(
                    lang == .zh ? "例如 ~/Code 或 /Users/you/projects" : "e.g. ~/Code or /Users/you/projects",
                    text: $pasteText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .onSubmit(addFromPasteText)
                .onChange(of: pasteText) { _, _ in pasteError = nil }

                if !pasteText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: addFromPasteText) {
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.piloGoldDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.piloGold.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.piloGold.opacity(0.45), lineWidth: 0.5)
            )

            if let err = pasteError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(err)
                        .font(.piloSerifCaption)
                }
                .foregroundStyle(Color.roseDanger)
            }
        }
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
            PiloLinkButton(
                title: lang == .zh ? "移除" : "Remove",
                tint: .roseDanger,
                action: { appState.removeWatchDirectory(url) }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
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

    private func addFromPasteText() {
        let raw = pasteText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        guard !raw.isEmpty else { return }

        let expanded: String = {
            if raw.hasPrefix("~") {
                return (raw as NSString).expandingTildeInPath
            }
            return raw
        }()

        let url = URL(fileURLWithPath: expanded).standardizedFileURL

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if !exists {
            pasteError = lang == .zh ? "这个路径找不到呢" : "Can't find this path"
            return
        }
        if !isDir.boolValue {
            pasteError = lang == .zh ? "这是个文件，不是目录" : "That's a file, not a folder"
            return
        }
        if appState.watchDirectories.contains(where: { $0.standardizedFileURL == url }) {
            pasteError = lang == .zh ? "已经在扫描清单里啦" : "Already in your watch list"
            return
        }

        appState.addWatchDirectory(url)
        pasteText = ""
        pasteError = nil
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
                    Text(Copy.KillSwitch.settingsToggleDescription(lang))
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
                                Text(Copy.KillSwitch.settingsKillSwitchTitle(lang))
                                    .font(.piloSection)
                                Text(Copy.KillSwitch.settingsKillSwitchDesc(lang))
                                    .font(.piloSerifSubtitle)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if appState.isKillSwitchActive {
                            HStack(spacing: 10) {
                                Text(String(format: Copy.KillSwitch.settingsKillSwitchActiveLabel(lang),
                                            appState.killSwitchRemainingHours))
                                    .font(.piloBody)
                                    .foregroundStyle(Color.amberWarn)
                                Spacer()
                                Button(Copy.KillSwitch.settingsKillSwitchRestoreButton(lang)) {
                                    appState.deactivateKillSwitch()
                                }
                                .buttonStyle(.piloPrimary)
                            }
                            .padding(.top, 6)
                        } else {
                            HStack {
                                Spacer()
                                Button(Copy.KillSwitch.settingsKillSwitchActivateButton(lang)) {
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
            PiloLinkButton(
                title: lang == .zh ? "恢复" : "Restore",
                tint: .piloBlue,
                action: { appState.setHidden(false, repoId: repo.id) }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
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

                // 「再看一次新手引导」入口 —— 用户可以随时重看 4 屏引导
                Button {
                    UserDefaults.standard.set(false, forKey: SettingsKey.hasCompletedOnboarding.rawValue)
                    UserDefaults.standard.synchronize()
                    openWindow(id: "onboarding")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 11))
                        Text(Copy.About.reopenOnboarding(lang))
                            .font(.piloSerifCaption)
                    }
                    .foregroundStyle(Color.piloGoldDark)
                }
                .buttonStyle(.plain)
                .help(Copy.About.reopenOnboardingHint(lang))

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
