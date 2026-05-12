import SwiftUI
import AppKit

/// v3.4 主面板：完全照 HTML 参考 scene 2 复刻——
/// 单卡片包顶部 header + 内部 2 列网格（180pt sidebar + flex detail）+ 信纸 commit 卡 + 按钮行
struct MainPanel: View {

    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        // 窗口本身就是面板——header 直接坐在窗口顶部，下方 2 栏铺满
        VStack(spacing: 0) {
            PanelHeader()
            Rectangle()
                .fill(Color.cloudDivider)
                .frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                PanelSidebar()
                    .frame(width: 220)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(Color.cloudDivider)
                    .frame(width: 1)
                PanelDetail()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paperCard)
        // PushConfirmDialog sheet：appState.pushSession 非 nil 时弹出
        // 必须 attach 在 MainPanel 而不是 MainWindowView —— 跟下面的 Markdown sheet
        // 在同一 view 上 SwiftUI 才能正确路由
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
        // Markdown 预览 sheet：appState.previewingDoc 非 nil 时弹出
        .sheet(item: Binding(
            get: { appState.previewingDoc },
            set: { if $0 == nil { appState.dismissPreview() } }
        )) { doc in
            // 找到 doc 对应 repo 的路径（selectedRepo）
            let repoPath = appState.repositories.first(where: { $0.id == appState.selectedRepoId })?.path ?? ""
            MarkdownPreviewSheet(doc: doc, repoPath: repoPath)
        }
    }
}

// MARK: - Panel Header（⭐金星 + 衬线标题 + 健康胶囊）

private struct PanelHeader: View {
    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        HStack(spacing: 12) {
            // 金色 5 角星图标
            Image(systemName: "star.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.piloGold)

            Text(lang == .zh ? "Pilo · 我的小邮局" : "Pilo · My Post Office")
                .font(.piloSerifTitle)
                .foregroundStyle(Color.inkPrimary)
                .tracking(0.5)

            Spacer()

            healthPill
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("CreamBg").opacity(0.35))
    }

    private var healthPill: some View {
        let healthy = appState.gitExecutablePath != nil
        // 注意：Pilo 只检测了 git 二进制是否存在，没真的验证 SSH key / GitHub PAT
        // / 网络。所以这里只能诚实说"Git 就绪"，不能假装 SSH/Token 都验证过。
        let text = healthy
            ? (lang == .zh ? "Git 就绪" : "Git ready")
            : (lang == .zh ? "未找到 git" : "git missing")
        let tint: Color = healthy ? .stampMint : .roseDanger

        return HStack(spacing: 5) {
            Image(systemName: healthy ? "checkmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Panel Sidebar（斜体宋体分组 + dot + name + count）

private struct PanelSidebar: View {
    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        ZStack {
            // 微微 tint 的 cream 背景（HTML: rgba(238,234,228,0.22)）
            Color("CreamBg").opacity(0.22)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Phase B: 三段分组——活跃 / 静默 / 沉寂

                    if !appState.activeRepos.isEmpty {
                        sidebarLabel(
                            text: Copy.Inventory.sidebarActive(lang) + " · \(appState.activeRepos.count)"
                        )
                        .padding(.top, PiloSpacing.s)
                        .padding(.bottom, PiloSpacing.xs)

                        ForEach(appState.activeRepos) { repo in
                            sidebarItem(repo)
                        }
                    }

                    if !appState.idleRepos.isEmpty {
                        sidebarLabel(
                            text: Copy.Inventory.sidebarIdle(lang) + " · \(appState.idleRepos.count)"
                        )
                        .padding(.top, PiloSpacing.m)
                        .padding(.bottom, PiloSpacing.xs)

                        ForEach(appState.idleRepos) { repo in
                            sidebarItem(repo)
                        }
                    }

                    if !appState.dormantRepos.isEmpty {
                        sidebarLabel(
                            text: Copy.Inventory.sidebarDormant(lang) + " · \(appState.dormantRepos.count)"
                        )
                        .padding(.top, PiloSpacing.m)
                        .padding(.bottom, PiloSpacing.xs)

                        ForEach(appState.dormantRepos) { repo in
                            sidebarItem(repo)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sidebarLabel(text: String) -> some View {
        Text(text)
            .font(.piloSerifSubtitle)
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 18)
    }

    private func sidebarItem(_ repo: Repository) -> some View {
        let isActive = repo.id == appState.selectedRepoId
        let stamp = Copy.Inventory.categoryStamp(repo.category, lang)
        return Button {
            appState.selectRepo(repo.id)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor(for: repo))
                    .frame(width: 9, height: 9)
                Text(repo.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !stamp.isEmpty {
                    Text(stamp)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(categoryStampColor(repo.category))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(categoryStampColor(repo.category).opacity(0.5), lineWidth: 0.6)
                        )
                }
                Spacer(minLength: 4)
                if let count = countLabel(for: repo) {
                    Text(count)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.piloBlue)
                }
            }
            .padding(.horizontal, isActive ? 16 : 18)
            .padding(.vertical, 11)
            .background(
                isActive
                    ? Color.piloBlue.opacity(0.12)
                    : Color.clear
            )
            .overlay(alignment: .leading) {
                if isActive {
                    Rectangle()
                        .fill(Color.piloBlue)
                        .frame(width: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: isActive ? .clear : Color.piloBlue.opacity(0.06))
    }

    /// 按 mood 区分 synced 状态下的颜色（Phase B：让"沉寂"项目视觉上更暗）。
    private func dotColor(for repo: Repository) -> Color {
        switch repo.statusSummary {
        case .ahead:       return .amberWarn
        case .behind:      return .lavenderInfo
        case .uncommitted: return .roseDanger
        case .synced:
            switch repo.mood {
            case .active:    return .mintSafe
            case .idle:      return .lavenderInfo.opacity(0.7)
            case .dying:     return .inkTertiary
            case .abandoned: return .inkTertiary.opacity(0.55)
            }
        }
    }

    private func categoryStampColor(_ cat: RepoCategory) -> Color {
        switch cat {
        case .work:       return .piloBlueDark
        case .personal:   return .piloGoldDark
        case .experiment: return .lavenderInfo
        case .unset:      return .inkTertiary
        }
    }

    private func countLabel(for repo: Repository) -> String? {
        if repo.aheadCount > 0 { return "\(repo.aheadCount)↑" }
        if repo.uncommittedCount > 0 { return "\(repo.uncommittedCount)" }
        return nil
    }
}

// MARK: - Panel Detail（衬线 hero + section + 信纸 commit + 操作按钮）

private struct PanelDetail: View {
    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    private var lang: Language { appState.language }

    /// "贴邮戳"自定义 popover 开关。当前 selectedRepo 一次只有一个 popover，
    /// 所以单 @State 即可。
    @State private var isStampPickerOpen = false

    /// "在 AI 中打开" 自定义 popover 开关
    @State private var isAIToolPickerOpen = false

    var body: some View {
        if let repo = currentRepo {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题行：repo 名（独享左侧）| 邮戳（trailing 独立位置）| PrivacyPill
                    // 真实邮件的物理：邮戳在右上角邮票区，跟地址/标签共存但不重叠
                    HStack(alignment: .center, spacing: 14) {
                        Text(repo.name)
                            .font(.piloSerifHero)
                            .tracking(0.5)
                            .foregroundStyle(Color.inkPrimary)
                        Spacer(minLength: 12)
                        stampOverlay(for: repo)
                            .frame(width: 56, height: 56)
                        PrivacyPill(repoId: repo.id)
                    }

                    // mono 路径 + 分支
                    Text(metaLine(for: repo))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.top, 8)

                    // 状态药丸
                    RepoStatusPill(repo: repo)
                        .padding(.top, 18)

                    // Resume Work：欢迎回来卡片（条件显示）
                    ResumeWorkCard(
                        repo: repo,
                        uncommittedFiles: appState.currentUncommittedFiles,
                        recentCommits: appState.currentRecentCommits
                    )
                    .padding(.top, 16)

                    // Phase B: 项目体检行（mood + README + tests）
                    healthRow(for: repo)
                        .padding(.top, 12)

                    // Phase B: abandoned 温和提醒（仅 abandoned 且无 work 显示）
                    if repo.mood == .abandoned && !repo.hasWork {
                        abandonedBanner(for: repo)
                            .padding(.top, 18)
                    }

                    // 三态 body
                    bodyContent(for: repo)

                    // 项目文档面板（条件显示）
                    ProjectDocsPanel(repoPath: repo.path, docs: appState.currentDocs)
                        .padding(.top, 18)

                    Spacer(minLength: 24)

                    actionsRow(for: repo)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            emptyDetail
        }
    }

    // MARK: - Phase B: Project Inventory pieces

    /// 标题右上方的邮戳 trigger —— **水印效果**：嵌入信纸的"已分类印记"感觉，
    /// 不抢标题视觉焦点，跟 cream paper 调融合。
    /// unset 时是 dashed 金圈 + sparkle，点击触发 popover；
    /// 已贴时是完整 illustrated 邮戳 + 0.62 opacity + multiply blend（水印感）。
    /// popover 内的 illustrated 仍保持 sharp（挑选时刻独享完整视觉冲击）。
    private func stampOverlay(for repo: Repository) -> some View {
        Button {
            isStampPickerOpen.toggle()
        } label: {
            StampBadge(category: repo.category, size: 60, style: .illustrated)
                .opacity(repo.category == .unset ? 1.0 : 0.62)      // 水印淡透
                .blendMode(repo.category == .unset ? .normal : .multiply)  // 跟纸融合
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(repo.category == .unset
              ? Copy.Inventory.categoryPickerPrompt(lang)
              : Copy.Inventory.categoryLabel(repo.category, lang))
        .popover(isPresented: $isStampPickerOpen, arrowEdge: .top) {
            stampPickerPopover(for: repo)
        }
    }

    /// 自定义 popover 内容：信纸 bg + 衬线标题 + OrnamentDivider + 3 枚印章 + 撕掉 link
    private func stampPickerPopover(for repo: Repository) -> some View {
        VStack(alignment: .center, spacing: 0) {
            // 标题
            Text(Copy.Inventory.categoryPickerPrompt(lang))
                .font(.piloSerifSubtitle)
                .italic()
                .foregroundStyle(Color.inkPrimary)

            OrnamentDivider(width: 140)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // 3 个印章选项
            HStack(spacing: 22) {
                ForEach([RepoCategory.work, .personal, .experiment], id: \.self) { cat in
                    stampPickerCard(cat: cat, currentCategory: repo.category, repoId: repo.id)
                }
            }

            // 撕掉邮戳 link，仅在已贴时显示
            if repo.category != .unset {
                Rectangle()
                    .fill(Color.cloudDivider.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 14)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.setCategory(.unset, repoId: repo.id)
                    }
                    isStampPickerOpen = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "scissors")
                            .font(.system(size: 9))
                        Text(Copy.Inventory.categoryPickerUnset(lang))   // "撕掉邮戳"
                            .font(.piloSerifCaption)
                            .italic()
                    }
                    .foregroundStyle(Color.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, repo.category == .unset ? 22 : 16)
        .frame(width: 360)
        .background(Color.piloPaper)
    }

    /// 单张印章卡片：印章 + 标签，hover 抬起，selected 加金色光晕环
    private func stampPickerCard(cat: RepoCategory, currentCategory: RepoCategory, repoId: UUID) -> some View {
        let isSelected = cat == currentCategory
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                appState.setCategory(cat, repoId: repoId)
            }
            isStampPickerOpen = false
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(Color.piloGold, lineWidth: 1.5)
                            .frame(width: 72, height: 72)
                    }
                    StampBadge(category: cat, size: 64)
                }
                .frame(width: 72, height: 72)

                Text(Copy.Inventory.categoryLabel(cat, lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(isSelected ? Color.inkPrimary : Color.inkSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloGold.opacity(0.08), cornerRadius: 10)
    }

    /// 健康体检行：mood / README 缺失 / 无测试 三类 chip。
    @ViewBuilder
    private func healthRow(for repo: Repository) -> some View {
        let pills = healthPills(for: repo)
        if !pills.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                    healthPill(text: pill.text, tint: pill.tint)
                }
            }
        }
    }

    private struct HealthPill: Hashable {
        let text: String
        let tint: HealthTint
        enum HealthTint: Hashable { case mood, missing, neutral }
    }

    private func healthPills(for repo: Repository) -> [HealthPill] {
        var pills: [HealthPill] = []
        // mood pill —— active 不显示（默认状态，留白）
        if repo.mood != .active, let days = repo.daysSinceLastCommit {
            let label = Copy.Inventory.moodLabel(repo.mood, lang) + " · " + Copy.Inventory.dormantDays(days: days, lang)
            pills.append(.init(text: label, tint: repo.mood == .abandoned ? .missing : .mood))
        }
        if !repo.hasReadme {
            pills.append(.init(text: Copy.Inventory.missingReadme(lang), tint: .missing))
        }
        if !repo.hasTests {
            pills.append(.init(text: Copy.Inventory.missingTests(lang), tint: .neutral))
        }
        return pills
    }

    private func healthPill(text: String, tint: HealthPill.HealthTint) -> some View {
        let (fg, bg): (Color, Color) = {
            switch tint {
            case .mood:    return (.piloGoldDark, Color.piloPaper)
            case .missing: return (.roseDanger.opacity(0.85), .roseDanger.opacity(0.08))
            case .neutral: return (.inkSecondary, .cloudDivider.opacity(0.4))
            }
        }()
        return Text(text)
            .font(.piloSerifCaption)
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(fg.opacity(0.25), lineWidth: 0.5)
            )
    }

    /// Abandoned 温和提醒卡。三个温和动作：保留 / 隐藏 / 在 Finder 里打开。
    private func abandonedBanner(for repo: Repository) -> some View {
        let days = repo.daysSinceLastCommit ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.piloGoldDark)
                Text(Copy.Inventory.abandonedTitle(tone, lang))
                    .font(.piloSerifTitle)
                    .foregroundStyle(Color.inkPrimary)
            }
            Text(Copy.Inventory.abandonedBody(tone, lang, days: days))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)

            HStack(spacing: 10) {
                Button(Copy.Inventory.abandonedActionKeep(lang)) {
                    // 不需要做什么，纯展示用户的"忽略"动作
                }
                .buttonStyle(MiniGhostButtonStyle())

                Button(Copy.Inventory.abandonedActionHide(lang)) {
                    appState.setHidden(true, repoId: repo.id)
                }
                .buttonStyle(MiniGhostButtonStyle())

                Button(Copy.Inventory.abandonedActionOpenFinder(lang)) {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: repo.path)]
                    )
                }
                .buttonStyle(MiniGhostButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.piloPaper.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.piloGold.opacity(0.4), lineWidth: 0.6)
        )
    }

    // MARK: - Three-state body

    @ViewBuilder
    private func bodyContent(for repo: Repository) -> some View {
        if repo.aheadCount > 0 {
            // 状态 1：有待推 commit
            SectionDivider(label: lang == .zh ? "— 待寄出的小信 —" : "— letters to send —")
                .padding(.top, 26)
                .padding(.bottom, 12)
            commitsList(for: repo)
        } else if repo.uncommittedCount > 0 {
            // 状态 2：只有未提交
            SectionDivider(label: lang == .zh ? "— 等待 commit 的草稿 —" : "— drafts waiting to commit —")
                .padding(.top, 26)
                .padding(.bottom, 12)
            uncommittedCard(for: repo)
        } else {
            // 状态 3：已同步——居中睡 Pilo
            syncedEmptyState
                .padding(.top, 40)
        }
    }

    private func uncommittedCard(for repo: Repository) -> some View {
        let text = lang == .zh
            ? "有 \(repo.uncommittedCount) 个未提交的修改 · 请在编辑器里 commit 后再回来推送"
            : "\(repo.uncommittedCount) uncommitted change\(repo.uncommittedCount == 1 ? "" : "s") · commit them in your editor, then come back to push"
        return Text(text)
            .font(.piloSerifSubtitle)
            .foregroundStyle(Color.roseDanger.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.roseDanger.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.roseDanger.opacity(0.25), lineWidth: 0.5)
            )
    }

    private var syncedEmptyState: some View {
        VStack(spacing: PiloSpacing.s) {
            PiloMascot(mood: .sleeping, size: 80, breathing: true)
            Text(lang == .zh ? "这个仓库一切都好" : "All good here")
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
            Text(lang == .zh ? "没什么要寄出的" : "nothing to send")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentRepo: Repository? {
        guard let id = appState.selectedRepoId else {
            // 默认选第一个 active
            return appState.activeRepos.first ?? appState.sortedRepos.first
        }
        return appState.repositories.first(where: { $0.id == id })
    }

    private func metaLine(for repo: Repository) -> String {
        // 按设计稿：只显示 path · branch，时间挪到 commit 卡片或省略
        var parts: [String] = [repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
        if let b = repo.currentBranch { parts.append(b) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func commitsList(for repo: Repository) -> some View {
        if appState.currentCommits.isEmpty {
            Text(lang == .zh ? "正在拉取 commit..." : "Loading commits...")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkTertiary)
                .padding(.vertical, PiloSpacing.s)
        } else {
            VStack(spacing: 8) {
                ForEach(appState.currentCommits.prefix(8)) { c in
                    commitRow(c)
                }
                if appState.currentCommits.count > 8 {
                    Text(lang == .zh
                         ? "…还有 \(appState.currentCommits.count - 8) 个"
                         : "…and \(appState.currentCommits.count - 8) more")
                        .font(.piloSerifSubtitle)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
    }

    private func commitRow(_ c: CommitSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(c.hash)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.piloGoldDark)
            Text(c.subject)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(RepoCard.relativeFormatter.localizedString(for: c.date, relativeTo: Date()))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }

    private func actionsRow(for repo: Repository) -> some View {
        HStack(spacing: 10) {
            // 推送（primary）
            Button {
                Task { await appState.beginPushSession(for: repo) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                    Text(lang == .zh ? "推送" : "Push")
                }
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(MiniPrimaryButtonStyle())
            .disabled(repo.aheadCount == 0 || repo.currentBranch == nil)

            // 在 AI 中打开 ▾ — menu 列出本机检测到的 AI 编辑器
            // 删了之前重复的"拉取"按钮（跟"在终端打开"是同一个 openTerminal 调用）
            aiLauncherButton(for: repo)

            // 在终端打开（ghost）
            Button(lang == .zh ? "在终端打开" : "Open in Terminal") {
                openTerminal(at: repo.path)
            }
            .buttonStyle(MiniGhostButtonStyle())
        }
    }

    @ViewBuilder
    private func aiLauncherButton(for repo: Repository) -> some View {
        if appState.detectedAITools.isEmpty {
            // 没检测到任何工具 → 禁用 button + hover 提示装哪些
            Button(action: {}) {
                HStack(spacing: 5) {
                    Text(Copy.AILauncher.openInButton(lang))
                }
            }
            .buttonStyle(MiniGhostButtonStyle())
            .disabled(true)
            .help(Copy.AILauncher.noToolsDetected(lang))
        } else {
            // 跟旁边"在终端打开"风格一致的 ghost button + 自定义 popover
            // 不用 macOS Menu —— 系统 menu 白底蓝高亮跟邮局美学冲突
            Button {
                isAIToolPickerOpen.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(Copy.AILauncher.openInButton(lang))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .buttonStyle(MiniGhostButtonStyle())
            .help(Copy.AILauncher.popoverTitle(lang))
            .popover(isPresented: $isAIToolPickerOpen, arrowEdge: .top) {
                aiToolPickerPopover(for: repo)
            }
        }
    }

    /// 自定义 popover：cream paper bg + 衬线标题 + OrnamentDivider + tool 卡片列表
    /// 视觉风格跟 stampPickerPopover 一致
    private func aiToolPickerPopover(for repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text(Copy.AILauncher.popoverTitle(lang))
                .font(.piloSerifSubtitle)
                .italic()
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity)

            OrnamentDivider(width: 120)
                .padding(.top, 6)
                .padding(.bottom, 12)

            // 工具卡片列表
            VStack(spacing: 2) {
                ForEach(appState.detectedAITools) { tool in
                    aiToolCard(tool, repoPath: repo.path)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 280)
        .background(Color.piloPaper)
    }

    /// 单张工具卡片：染色 icon + italic Songti 名字 + hover 金色高亮
    private func aiToolCard(_ tool: AITool, repoPath: String) -> some View {
        Button {
            tool.launch(repoPath: repoPath)
            isAIToolPickerOpen = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(tool.tintColor)
                    .frame(width: 18, alignment: .center)
                Text(tool.displayName)
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloGold.opacity(0.08), cornerRadius: 6)
    }

    private func openTerminal(at path: String) {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private var emptyDetail: some View {
        VStack(spacing: PiloSpacing.l) {
            Spacer()
            PiloMascot(mood: .sleeping, size: 96, breathing: true)
            Text(lang == .zh ? "选一个仓库吧 ✨" : "Pick a repo ✨")
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mini button styles（匹配 HTML 的 .btn-mini-primary / .btn-mini-ghost）

private struct MiniPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                (configuration.isPressed ? Color.piloBlueDark : Color.piloBlue)
                    .opacity(enabled ? 1 : 0.5)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct MiniGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(Color.inkSecondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(configuration.isPressed
                          ? Color.cloudDivider.opacity(0.4)
                          : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.cloudDivider, lineWidth: 0.5)
                    )
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 邮戳印章组件（可复用）

/// 圆形邮戳。三种渲染风格：
///   - unset：金色虚线圆 + sparkle 小光（暗示"还没贴"），无 style 区分
///   - .illustrated：完整插画 asset（用于 popover 64pt"挑邮戳"时刻）
///   - .glyph：Songti 楷书单字 + 实色圆（用于 trigger 20pt"已贴轻量标记"）
///
/// 分层逻辑：完整插画是"挑选的高光"，简笔字戳是"贴好的确认"，两者并存避免
/// 在小尺寸上糊掉细节又能在 trigger 处跟 Songti 标题视觉和谐。
private struct StampBadge: View {
    enum Style {
        case illustrated   // 完整插画 asset，适合 ≥48pt
        case glyph         // Songti 楷书 + 实色圆，适合 ≤24pt
    }

    let category: RepoCategory
    let size: CGFloat
    var style: Style = .illustrated

    var body: some View {
        Group {
            if category == .unset {
                unsetBadge()
            } else {
                switch style {
                case .illustrated: illustratedBadge
                case .glyph:       glyphBadge()
                }
            }
        }
    }

    private func unsetBadge() -> some View {
        let dashStroke = max(0.9, size * 0.04)
        let dashLength = max(2.5, size * 0.10)
        let dashGap    = max(2.0, size * 0.08)
        return Image(systemName: "sparkle")
            .font(.system(size: size * 0.42))
            .foregroundStyle(Color.piloGold.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.piloGold.opacity(0.55),
                            style: StrokeStyle(lineWidth: dashStroke,
                                               dash: [dashLength, dashGap]))
            )
            .rotationEffect(.degrees(-8))
            .opacity(0.82)
    }

    /// 完整插画邮戳：用户提供的 illustrated 邮戳 asset。
    /// **本体保持 sharp**（popover 挑选时刻用）—— 不带 opacity / blend / shadow。
    /// trigger 处的"水印感"由 stampOverlay 外层 wrap 实现（保留分层灵活性）。
    private var illustratedBadge: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-8))
    }

    /// 双线圆环 + 单色透明字戳，模拟"盖在纸上的油墨痕迹"。
    /// 视觉原则：
    ///   1. 轮廓是线条不是填充 —— paper 底色从中央透出来
    ///   2. 双线圆环（外粗内细），邮戳的标志结构
    ///   3. 字跟描边同色（单色油墨）
    ///   4. -8° 倾斜 + 85% opacity，盖印的物理不完美感
    /// 参数按 size 比例缩放，22pt 当 trigger / 60pt 当 overlay 都视觉一致。
    private func glyphBadge() -> some View {
        let outerStroke  = max(1.2, size * 0.045)
        let innerStroke  = max(0.5, size * 0.018)
        let innerPadding = max(2.5, size * 0.085)
        return ZStack {
            // 外圈实线
            Circle()
                .strokeBorder(stampColor.opacity(0.85), lineWidth: outerStroke)
            // 内圈细线
            Circle()
                .strokeBorder(stampColor.opacity(0.55), lineWidth: innerStroke)
                .padding(innerPadding)
            // 中央楷书字 —— 类别色单色油墨
            Text(stampGlyph)
                .font(.custom("Songti SC", size: size * 0.5).weight(.semibold))
                .foregroundStyle(stampColor.opacity(0.9))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
        .opacity(0.85)
        .shadow(color: stampColor.opacity(0.18), radius: 1.2, y: 0.6)
    }

    /// 完整插画 asset 名
    private var assetName: String {
        switch category {
        case .work:       return "CategoryStampWork"
        case .personal:   return "CategoryStampPersonal"
        case .experiment: return "CategoryStampExperiment"
        case .unset:      return ""
        }
    }

    /// 简笔字戳：楷书单字
    private var stampGlyph: String {
        switch category {
        case .work:       return "工"
        case .personal:   return "私"
        case .experiment: return "试"
        case .unset:      return ""
        }
    }

    /// 简笔字戳的背景色（跟 sidebar dot / health pill 类别色一致）
    private var stampColor: Color {
        switch category {
        case .work:       return .piloBlue
        case .personal:   return .piloGold
        case .experiment: return .lavenderInfo
        case .unset:      return .piloGold
        }
    }
}
