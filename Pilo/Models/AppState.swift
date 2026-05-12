import Foundation
import SwiftUI
import Observation

/// 跨 Scene 共享的应用状态。使用 Observation 框架而非 ObservableObject（macOS 14+）。
///
/// 注意：本类 `@MainActor` 隔离，所有 UI 读写都是主线程；后台任务（actor）通过
/// 显式 `await` 跨边界更新状态。
@MainActor
@Observable
final class AppState {

    // MARK: - 后端

    let gitClient: GitClient
    let scanner: RepoScanner
    let pushExecutor: PushExecutor
    let secretScanner: SecretScanner
    let commitGuard: CommitGuardScanner
    let visibilityClient: GitHubVisibilityClient
    private let fsMonitor: FSEventMonitor

    // MARK: - 仓库可见性缓存（24h TTL）

    /// repoId → (visibility, fetchedAt)
    var visibilityCache: [UUID: (vis: GitHubVisibility, at: Date)] = [:]
    private static let visibilityTTL: TimeInterval = 24 * 3600

    /// 给视图用：拿当前 repo 缓存的可见性。nil = 没查过 OR 已过期
    func cachedVisibility(for repoId: UUID) -> GitHubVisibility? {
        guard let entry = visibilityCache[repoId] else { return nil }
        if Date().timeIntervalSince(entry.at) > Self.visibilityTTL { return nil }
        return entry.vis
    }

    // MARK: - Push 会话

    var pushSession: PushSession?

    /// 用户当前面对的 finding 是否在选择"标记为误报"的范围。nil 表示没有该 popover。
    var falsePositivePickerTarget: ScanFinding?

    /// 最近一次"加入 .gitignore"的结果，用于触发 GitignoreActionSheet。
    var lastGitignoreAction: GitignoreActionState?

    struct GitignoreActionState: Sendable, Identifiable {
        let id = UUID()
        let kind: CommitGuardFinding.Kind
        let filePath: String
        let addedLines: [String]
        let alreadyPresent: [String]
        let gitignorePath: String
        let advisedAction: String     // 给用户的下一步说明
    }

    // MARK: - Kill switch（PRD §4.8）

    /// 直接由 UserDefaults 镜像；computed 的 isActive 才是 UI 应该读的。
    var killSwitchExpiresAt: Date?

    /// 真正的状态：当前 kill switch 是否在生效中。
    /// **不要**用 stored 属性——computed 保证读到当下时间的真值，不会因为 timer 没醒而误报。
    var isKillSwitchActive: Bool {
        guard let d = killSwitchExpiresAt else { return false }
        return d > Date()
    }

    var killSwitchRemainingHours: Int {
        guard let d = killSwitchExpiresAt else { return 0 }
        let s = max(0, d.timeIntervalSinceNow)
        return Int(ceil(s / 3600))
    }

    private var killSwitchExpiryTask: Task<Void, Never>?

    /// 当前消费 FSEvent 的任务；watch dirs 改变时取消重启
    private var watcherTask: Task<Void, Never>?

    // MARK: - 仓库

    var repositories: [Repository] = []
    var selectedRepoId: UUID?
    var isInitialScanComplete: Bool = false
    var scanProgressMessage: String?
    var isScanning: Bool = false

    /// 当前选中 repo 的待推送 commit 列表（panel detail 实时展示）
    var currentCommits: [CommitSummary] = []
    private var commitsFetchTask: Task<Void, Never>?

    // === Resume Work + 项目文档（Phase B v2）===
    /// 当前选中 repo 的未提交文件清单（草稿）
    var currentUncommittedFiles: [UncommittedFile] = []
    /// 当前选中 repo 的最近 commit（"最近寄出过"）
    var currentRecentCommits: [CommitSummary] = []
    /// 当前选中 repo 的项目文档列表（仅 visible）
    var currentDocs: [RepoDoc] = []
    /// 当前选中 repo 的"已藏起"文档列表（hiddenDocPaths 命中）
    var currentHiddenDocs: [RepoDoc] = []
    private var resumeFetchTask: Task<Void, Never>?
    private var docsFetchTask: Task<Void, Never>?

    // === Markdown 预览（Phase B v3）===
    /// 当前正在预览的文档。nil → 预览 sheet 关闭。
    var previewingDoc: RepoDoc?
    /// 预览的 markdown 内容（异步加载）；nil = 加载中，empty = 失败/空文件
    var previewDocument: MarkdownDocument?
    /// 预览加载错误（无法读 / 不是文本 / 太大）
    var previewError: PreviewError?
    private var previewLoadTask: Task<Void, Never>?

    enum PreviewError: Error, Sendable, Equatable {
        case fileNotFound
        case notText
        case tooLarge
        case empty
    }

    /// Phase B (Project Inventory) 三段分组：活跃 / 静默 / 沉寂
    /// 优先级原则：**任何有 work 的仓库都是 active**（用户需要做事），不论 mood。
    /// 没 work 的按 mood 切分到三档。

    /// 活跃 —— 有 work（待推/未提交）或最近 7 天有 commit。
    var activeRepos: [Repository] {
        sortedRepos.filter { repo in
            if repo.hasWork { return true }
            return repo.mood == .active
        }
    }

    /// 静默 —— 没 work，最近 7-30 天有过 commit（暂时没动但还活着）。
    var idleRepos: [Repository] {
        sortedRepos.filter { repo in
            if repo.hasWork { return false }
            return repo.mood == .idle
        }
    }

    /// 沉寂 —— 没 work，30 天以上没动过（dying + abandoned 合并展示）。
    var dormantRepos: [Repository] {
        sortedRepos.filter { repo in
            if repo.hasWork { return false }
            return repo.mood == .dying || repo.mood == .abandoned
        }
    }

    /// 向后兼容：旧代码（如 dotColor）仍使用 sleepingRepos = idle + dormant。
    var sleepingRepos: [Repository] {
        idleRepos + dormantRepos
    }

    var pendingRepos: [Repository] {
        repositories.filter { $0.hasWork && !$0.isHidden }
    }

    var sortedRepos: [Repository] {
        repositories
            .filter { !$0.isHidden }
            .sorted { lhs, rhs in
                // 有 work 的在前；同组内按 lastCommitDate 倒序
                if lhs.hasWork != rhs.hasWork { return lhs.hasWork }
                return (lhs.lastCommitDate ?? .distantPast) > (rhs.lastCommitDate ?? .distantPast)
            }
    }

    // MARK: - 环境

    /// 启动时一次性 `which git` 解析的可执行路径。nil 表示未安装。
    var gitExecutablePath: String?
    var gitVersion: String?

    var watchDirectories: [URL] = []

    // MARK: - 设置（镜像 UserDefaults）

    var tone: Tone = AppSettingsDefaults.tone
    var language: Language = .systemDefault

    // MARK: - 启动

    init() {
        let git = GitClient()
        self.gitClient = git
        self.scanner = RepoScanner(gitClient: git)
        self.pushExecutor = PushExecutor(gitClient: git)
        self.secretScanner = SecretScanner()
        self.commitGuard = CommitGuardScanner()
        self.visibilityClient = GitHubVisibilityClient()
        self.fsMonitor = FSEventMonitor()
        // 恢复 kill switch 状态
        if let ts = UserDefaults.standard.object(forKey: SettingsKey.killSwitchExpiresAt.rawValue) as? TimeInterval {
            let restored = Date(timeIntervalSince1970: ts)
            if restored > Date() {
                self.killSwitchExpiresAt = restored
                // init 里直接 Task 调度过期清理；MainActor 上下文，安全
                let weakSelf = self
                killSwitchExpiryTask = Task { [weak weakSelf] in
                    let interval = restored.timeIntervalSinceNow
                    if interval > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                    await MainActor.run {
                        guard let s = weakSelf else { return }
                        if let exp = s.killSwitchExpiresAt, exp <= Date() {
                            s.killSwitchExpiresAt = nil
                            UserDefaults.standard.removeObject(forKey: SettingsKey.killSwitchExpiresAt.rawValue)
                        }
                    }
                }
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsKey.killSwitchExpiresAt.rawValue)
            }
        }
        self.watchDirectories = WatchDirectoriesStorage.load()
        loadToneFromDefaults()
        loadRepositoriesFromDisk()
        // 在 MainActor 的下一个 tick 启动后端检测和首扫；
        // 用户看到的是先显示缓存数据，然后异步刷新。
        Task { [weak self] in
            await self?.bootstrap()
        }
    }

    /// 由 PiloApp 在 Scene `.task` 中调用一次：检测 git + 首次扫描。
    func bootstrap() async {
        await gitClient.detect()
        self.gitExecutablePath = await gitClient.executablePath
        self.gitVersion = await gitClient.version

        // 即使没有 watch dirs 也标记完成；空状态由 view 决定显示什么
        if watchDirectories.isEmpty {
            isInitialScanComplete = true
            return
        }
        await rescan()
        restartFSMonitor()
    }

    /// 用当前 watchDirectories 重启 FSEvent 监听，并消费事件做 500ms 防抖后触发 rescan。
    private func restartFSMonitor() {
        watcherTask?.cancel()
        fsMonitor.start(paths: watchDirectories)
        let stream = fsMonitor.events
        watcherTask = Task { [weak self] in
            var pending = false
            for await event in stream {
                _ = event
                if Task.isCancelled { return }
                if pending { continue }
                pending = true
                // 500ms 防抖：所有事件汇成一次 rescan
                try? await Task.sleep(nanoseconds: 500_000_000)
                pending = false
                await self?.rescan()
            }
        }
    }

    /// 全量重扫。设置 / Onboarding 改变 watch dirs 后调用。
    func rescan() async {
        guard !isScanning else { return }
        guard gitExecutablePath != nil else {
            isInitialScanComplete = true
            return
        }
        isScanning = true
        scanProgressMessage = Copy.menubarScanInProgress(tone)
        let dirs = watchDirectories
        let scanned = await scanner.scan(watchDirs: dirs)
        applyScanResult(scanned)
        isScanning = false
        scanProgressMessage = nil
        isInitialScanComplete = true
    }

    // MARK: - Tone

    private func loadToneFromDefaults() {
        if let raw = UserDefaults.standard.string(forKey: SettingsKey.tone.rawValue),
           let parsed = Tone(rawValue: raw) {
            self.tone = parsed
        }
        if let raw = UserDefaults.standard.string(forKey: SettingsKey.language.rawValue),
           let parsed = Language(rawValue: raw) {
            self.language = parsed
        }
        // 首次启动没存过则按系统 Locale 推断；已经在 property 默认值里处理过
    }

    func updateTone(_ newTone: Tone) {
        self.tone = newTone
        UserDefaults.standard.set(newTone.rawValue, forKey: SettingsKey.tone.rawValue)
    }

    func updateLanguage(_ newLanguage: Language) {
        self.language = newLanguage
        UserDefaults.standard.set(newLanguage.rawValue, forKey: SettingsKey.language.rawValue)
    }

    // MARK: - Watch directories

    func addWatchDirectory(_ url: URL) {
        guard !watchDirectories.contains(url) else { return }
        watchDirectories.append(url)
        WatchDirectoriesStorage.save(watchDirectories)
        Task { [weak self] in
            await self?.rescan()
            self?.restartFSMonitor()
        }
    }

    func removeWatchDirectory(_ url: URL) {
        watchDirectories.removeAll { $0 == url }
        WatchDirectoriesStorage.save(watchDirectories)
        Task { [weak self] in
            await self?.rescan()
            self?.restartFSMonitor()
        }
    }

    // MARK: - 仓库持久化

    func loadRepositoriesFromDisk() {
        let url = AppPaths.stateJSON
        guard let data = try? Data(contentsOf: url) else {
            self.repositories = []
            return
        }
        do {
            let store = try JSONDecoder.pilo.decode(RepositoryStore.self, from: data)
            self.repositories = store.repositories
        } catch {
            // 损坏的 state.json 不能阻塞启动；备份后清空
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("state.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            self.repositories = []
        }
    }

    func saveRepositoriesToDisk() {
        let store = RepositoryStore(version: RepositoryStore.currentVersion, repositories: repositories)
        do {
            let data = try JSONEncoder.pilo.encode(store)
            try data.write(to: AppPaths.stateJSON, options: [.atomic])
        } catch {
            // 持久化失败不致命；后续 phase 加入日志
        }
    }

    // MARK: - Push 会话流程

    /// 由 RepoDetailView 的 Push 按钮触发：拉取 commit 列表 + 解析 upstream + 跑安全扫描，
    /// 然后把 sheet 切到 preflight 状态。
    func beginPushSession(for repo: Repository) async {
        guard let branch = repo.currentBranch else { return }
        let repoURL = URL(fileURLWithPath: repo.path)
        let defaultRemote = repo.defaultPushRemote
        let upstream = await gitClient.branchUpstream(repo: repoURL, branch: branch)
        let willSetUpstream = upstream == nil
        let remote = upstream?.remote ?? defaultRemote
        let upstreamBranch = upstream?.branch ?? branch

        // 1) commit 列表
        let commits = await gitClient.pendingPushCommits(
            repo: repoURL,
            branch: upstreamBranch,
            remote: remote
        )

        // 2) 安全扫描（如果 kill switch 没启用）
        var findings: [ScanFinding] = []
        var guardFindings: [CommitGuardFinding] = []
        var scanSkipped = false
        if isKillSwitchActive {
            scanSkipped = true
        } else if !commits.isEmpty {
            // SecretScanner（diff 内容）
            if let diff = await gitClient.diffForPush(repo: repoURL, branch: upstreamBranch, remote: remote) {
                let diffLines = DiffParser.parse(diff)
                findings = await secretScanner.scan(
                    diffLines: diffLines,
                    repoId: repo.id,
                    falsePositiveMarks: repo.falsePositiveMarks
                )
            }
            // CommitGuardScanner（文件清单 + 大小）
            let changed = await gitClient.changedFilesForPush(
                repo: repoURL, branch: upstreamBranch, remote: remote
            )
            // 闭包捕获 self 不能直接 await actor 方法；把 gitClient 局部捕获
            let gc = gitClient
            guardFindings = await commitGuard.scan(
                changedFiles: changed,
                sizeFor: { path in await gc.blobSize(repo: repoURL, path: path) },
                repoId: repo.id
            )
        }

        let preflight = PushSession.Preflight(
            repoId: repo.id,
            repoPath: repo.path,
            repoName: repo.name,
            remote: remote,
            branch: branch,
            willSetUpstream: willSetUpstream,
            commits: commits,
            findings: findings,
            guardFindings: guardFindings,
            scanSkippedByKillSwitch: scanSkipped,
            bypassConfirmed: false,
            ignoredIds: []
        )
        self.pushSession = PushSession(preflight: preflight)
    }

    // MARK: - Session-scoped 忽略

    /// 仅本次忽略——不持久化。下次 push 这个 finding 还会出现。
    func ignoreOnce(findingId: UUID) {
        guard let session = pushSession, case .preflight(var pre) = session.state else { return }
        pre.ignoredIds.insert(findingId)
        var s = session
        s.state = .preflight(pre)
        pushSession = s
    }

    // MARK: - 加入 .gitignore

    /// 给定一个 commit guard finding，把它建议的模式追加到 repo 根 .gitignore。
    /// 触发 lastGitignoreAction，让 GitignoreActionSheet 弹出告诉用户后续步骤。
    func addToGitignore(for finding: CommitGuardFinding) {
        guard let repo = repositories.first(where: { $0.id == finding.repoId }) else { return }
        guard case .addToGitignore(let pattern) = finding.suggestion else { return }
        do {
            let result = try GitignoreEditor.append(pattern: pattern, toRepoAt: repo.path)
            let advised: String
            switch finding.kind {
            case .envFile, .privateKey:
                advised = """
                ⚠️ 重要：.gitignore 只阻止**未来**的提交。这次 push 里已经存在的文件不会因此消失——它一旦上 GitHub，全世界都能看到。

                建议：
                  1. 立即在密钥服务商后台 revoke 涉及的 token / 密钥
                  2. 重新生成新 key，放到 .env 而非源码
                  3. 如果需要把这个文件从历史中彻底抹掉，请在终端运行：
                     git filter-repo --path \(finding.filePath) --invert-paths
                """
            case .buildArtifact, .dsStore, .publicKey:
                advised = "已加入 .gitignore——未来不会再误推。如果想从历史中也清理，可在终端用 git filter-repo。"
            case .largeFile, .oversizeBlocked:
                advised = "大文件建议走 Git LFS：\n  brew install git-lfs\n  git lfs install\n  git lfs track \"\(finding.filePath)\""
            }
            self.lastGitignoreAction = GitignoreActionState(
                kind: finding.kind,
                filePath: finding.filePath,
                addedLines: result.addedLines,
                alreadyPresent: result.alreadyPresent,
                gitignorePath: result.gitignorePath,
                advisedAction: advised
            )
            // 同步从 preflight 移除这条（用户已经处理过了）
            ignoreOnce(findingId: finding.id)
        } catch {
            // .gitignore 写不进去——通常是权限问题；做个温和提示
            self.lastGitignoreAction = GitignoreActionState(
                kind: finding.kind,
                filePath: finding.filePath,
                addedLines: [],
                alreadyPresent: [],
                gitignorePath: "(写入失败)",
                advisedAction: "写不进去 .gitignore：\(error.localizedDescription)\n建议手动编辑仓库根的 .gitignore。"
            )
        }
    }

    /// BypassConfirmDialog 验证通过后调用：用户已输入仓库名解锁推送。
    func confirmBypassForCurrentPush() {
        guard let session = pushSession,
              case .preflight(var pre) = session.state else { return }
        pre.bypassConfirmed = true
        var s = session
        s.state = .preflight(pre)
        pushSession = s
    }

    // MARK: - 误报标记

    /// 用户从 finding 卡片点"标记为误报"时调用。
    func markFalsePositive(_ finding: ScanFinding, scope: FalsePositiveMark.Scope) async {
        guard let repoIdx = repositories.firstIndex(where: { $0.id == finding.repoId }) else { return }
        guard let rule = await secretScanner.rule(id: finding.ruleId) else { return }
        let mark = FalsePositiveMark(rule: rule, scope: scope, finding: finding)
        repositories[repoIdx].falsePositiveMarks.append(mark)
        saveRepositoriesToDisk()

        // 从当前 preflight findings 立即把命中的去掉
        if let session = pushSession, case .preflight(var pre) = session.state {
            pre.findings.removeAll { mark.matches($0) }
            var s = session
            s.state = .preflight(pre)
            pushSession = s
        }
        // 关闭范围选择器
        falsePositivePickerTarget = nil
    }

    // MARK: - Kill switch

    func activateKillSwitch(durationHours: Int = 24) {
        let expiry = Date().addingTimeInterval(TimeInterval(durationHours) * 3600)
        self.killSwitchExpiresAt = expiry
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: SettingsKey.killSwitchExpiresAt.rawValue)
        scheduleKillSwitchExpiry(at: expiry)
    }

    func deactivateKillSwitch() {
        self.killSwitchExpiresAt = nil
        UserDefaults.standard.removeObject(forKey: SettingsKey.killSwitchExpiresAt.rawValue)
        killSwitchExpiryTask?.cancel()
        killSwitchExpiryTask = nil
    }

    private func scheduleKillSwitchExpiry(at date: Date) {
        killSwitchExpiryTask?.cancel()
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        killSwitchExpiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                if let exp = self.killSwitchExpiresAt, exp <= Date() {
                    self.killSwitchExpiresAt = nil
                    UserDefaults.standard.removeObject(forKey: SettingsKey.killSwitchExpiresAt.rawValue)
                }
            }
        }
    }

    /// PushConfirmDialog 的"推送"按钮调用。从 preflight → running → completed。
    func executePush() async {
        guard let session = pushSession,
              case .preflight(let pre) = session.state else { return }
        // 安全闸门：critical findings 必须 bypass 才能继续。UI 应该已经禁推，这里再兜底。
        guard pre.canPushDirectly else { return }

        // 切到 running 状态
        var s = session
        s.state = .running(.init(remote: pre.remote))
        pushSession = s

        let report = await pushExecutor.push(
            repoURL: URL(fileURLWithPath: pre.repoPath),
            repoId: pre.repoId,
            repoName: pre.repoName,
            remote: pre.remote,
            branch: pre.branch,
            commitCount: pre.commits.count,
            setUpstream: pre.willSetUpstream
        )

        // 推送成功 → 该仓库 aheadCount 清零（后续 fetch 会校准；先乐观更新）
        if report.outcome.isSuccess {
            if let idx = repositories.firstIndex(where: { $0.id == pre.repoId }) {
                repositories[idx].aheadCount = 0
                saveRepositoriesToDisk()
            }
        }

        var s2 = session
        s2.state = .completed(report)
        pushSession = s2
    }

    // MARK: - 隐藏 / 取消隐藏仓库

    // MARK: - 选中 repo + 加载 commit 列表

    /// 选中 repo 时拉取真实的待推送 commit（异步，UI 显示加载态前留空数组）。
    func selectRepo(_ id: UUID?) {
        selectedRepoId = id
        currentCommits = []
        currentUncommittedFiles = []
        currentRecentCommits = []
        currentDocs = []
        currentHiddenDocs = []
        commitsFetchTask?.cancel()
        resumeFetchTask?.cancel()
        docsFetchTask?.cancel()
        guard let id, let repo = repositories.first(where: { $0.id == id }) else { return }
        let repoURL = URL(fileURLWithPath: repo.path)

        // 0) 记录"上次见你"时间——下次打开就有意义了。
        //    注意：必须在这里更新（不是 commit 时也不是 push 时），
        //    "上次见你"的语义就是"上次用户在 Pilo 里看过这个 repo"。
        if let idx = repositories.firstIndex(where: { $0.id == id }) {
            repositories[idx].lastViewedDate = Date()
            saveRepositoriesToDisk()
        }

        // 1) 待推送 Commits
        if let branch = repo.currentBranch {
            let upstreamRemote = repo.defaultPushRemote
            commitsFetchTask = Task { [weak self] in
                let commits = await self?.gitClient.pendingPushCommits(
                    repo: repoURL, branch: branch, remote: upstreamRemote
                ) ?? []
                await MainActor.run {
                    guard let self, self.selectedRepoId == id else { return }
                    self.currentCommits = commits
                }
            }
        }

        // 2) Resume Work：草稿 + 最近寄出
        resumeFetchTask = Task { [weak self] in
            let uncommitted = await self?.gitClient.uncommittedFiles(repo: repoURL, limit: 10) ?? []
            let recent = await self?.gitClient.recentCommits(repo: repoURL, limit: 5) ?? []
            await MainActor.run {
                guard let self, self.selectedRepoId == id else { return }
                self.currentUncommittedFiles = uncommitted
                self.currentRecentCommits = recent
            }
        }

        // 3) 项目文档（按需扫，不阻塞 UI）
        let hiddenPaths = repo.hiddenDocPaths
        docsFetchTask = Task { [weak self] in
            // 文档扫盘是纯 FileManager，但仍放到后台 Task 避免占用 MainActor
            let docs = await Task.detached(priority: .userInitiated) {
                RepoDocsIndexer.index(repoPath: repo.path)
            }.value
            // 按用户的"已藏起"清单分两堆
            let visible = docs.filter { !hiddenPaths.contains($0.relativePath) }
            let hidden = docs.filter { hiddenPaths.contains($0.relativePath) }
            await MainActor.run {
                guard let self, self.selectedRepoId == id else { return }
                self.currentDocs = visible
                self.currentHiddenDocs = hidden
            }
        }

        // 4) Visibility（按需 + 缓存）
        if cachedVisibility(for: id) == nil,
           let firstURL = repo.remotes.first?.url,
           let owner = GitHubVisibilityClient.parseOwnerRepo(from: firstURL) {
            Task { [weak self] in
                guard let self else { return }
                let vis = await self.visibilityClient.fetch(owner)
                await MainActor.run {
                    self.visibilityCache[id] = (vis, Date())
                }
            }
        }
    }

    /// Phase B: 给仓库贴 / 改 / 撕"投递箱"标签。立即持久化。
    func setCategory(_ category: RepoCategory, repoId: UUID) {
        guard let idx = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        guard repositories[idx].category != category else { return }
        repositories[idx].category = category
        saveRepositoriesToDisk()
    }

    func setHidden(_ hidden: Bool, repoId: UUID) {
        guard let idx = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        repositories[idx].isHidden = hidden
        // 隐藏当前选中的，要重选
        if hidden && selectedRepoId == repoId {
            selectedRepoId = sortedRepos.first?.id
        }
        saveRepositoriesToDisk()
    }

    var hiddenRepos: [Repository] {
        repositories.filter { $0.isHidden }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - 文档隐藏（在小邮局内分拣）

    /// 把一份文档"藏起来"——不删文件，仅在 doc panel 默认隐藏。立即持久化。
    func hideDoc(_ doc: RepoDoc, repoId: UUID) {
        guard let idx = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        repositories[idx].hiddenDocPaths.insert(doc.relativePath)
        saveRepositoriesToDisk()
        // 立即从 currentDocs 移到 currentHiddenDocs（避免要等下次 selectRepo 才反映）
        if selectedRepoId == repoId,
           let removed = currentDocs.first(where: { $0.relativePath == doc.relativePath }) {
            currentDocs.removeAll { $0.relativePath == doc.relativePath }
            if !currentHiddenDocs.contains(where: { $0.relativePath == doc.relativePath }) {
                currentHiddenDocs.append(removed)
            }
        }
    }

    /// 把文档"翻出来"——从隐藏列表中移除。
    func unhideDoc(_ doc: RepoDoc, repoId: UUID) {
        guard let idx = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        repositories[idx].hiddenDocPaths.remove(doc.relativePath)
        saveRepositoriesToDisk()
        if selectedRepoId == repoId,
           let removed = currentHiddenDocs.first(where: { $0.relativePath == doc.relativePath }) {
            currentHiddenDocs.removeAll { $0.relativePath == doc.relativePath }
            if !currentDocs.contains(where: { $0.relativePath == doc.relativePath }) {
                currentDocs.append(removed)
                // 重新按 indexer 排序规则排（kind priority + mtime）
                currentDocs.sort { lhs, rhs in
                    let lp = Self.docSortPriority(lhs.kind)
                    let rp = Self.docSortPriority(rhs.kind)
                    if lp != rp { return lp < rp }
                    return lhs.modifiedAt > rhs.modifiedAt
                }
            }
        }
    }

    /// 镜像 RepoDocsIndexer.sortPriority（同样规则保持 unhide 后顺序一致）。
    private static func docSortPriority(_ kind: RepoDoc.Kind) -> Int {
        switch kind {
        case .readme:          return 0
        case .aiInstructions:  return 1
        case .architecture:    return 2
        case .prd:             return 3
        case .todo:            return 4
        case .changelog:       return 5
        case .contributing:    return 6
        case .license:         return 7
        case .notes:           return 8
        case .generic:         return 99
        }
    }

    // MARK: - Markdown 预览

    /// 打开预览 sheet。异步读文件 + 解析；状态通过 previewDocument / previewError 传递。
    func presentPreview(for doc: RepoDoc, in repoPath: String) {
        previewingDoc = doc
        previewDocument = nil
        previewError = nil
        previewLoadTask?.cancel()

        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(doc.relativePath)
        previewLoadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.loadAndParse(at: fullPath)
            }.value
            await MainActor.run {
                guard let self, self.previewingDoc?.id == doc.id else { return }
                switch result {
                case .success(let document):
                    if document.blocks.isEmpty && !document.truncated {
                        self.previewError = .empty
                    } else if document.truncated {
                        self.previewError = .tooLarge
                    } else {
                        self.previewDocument = document
                    }
                case .failure(let err):
                    self.previewError = err
                }
            }
        }
    }

    func dismissPreview() {
        previewingDoc = nil
        previewDocument = nil
        previewError = nil
        previewLoadTask?.cancel()
        previewLoadTask = nil
    }

    /// 读文件 + 解析。返回 success(doc) 或 failure(具体错误)。
    /// 在后台 Task.detached 上跑，避免 MainActor 阻塞。
    nonisolated private static func loadAndParse(at url: URL) -> Result<MarkdownDocument, PreviewError> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.fileNotFound)
        }
        if data.count > MarkdownRenderer.maxFileBytes {
            return .failure(.tooLarge)
        }
        if data.isEmpty {
            return .failure(.empty)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notText)
        }
        let doc = MarkdownRenderer.parse(text)
        return .success(doc)
    }

    func dismissPushSession() {
        pushSession = nil
        // 推送后做一次轻量 rescan 校准 ahead/behind
        Task { [weak self] in
            await self?.rescan()
        }
    }

    func applyScanResult(_ scanned: [Repository]) {
        // 按 pathHash 合并：保留旧条目的用户手设字段（category / customTags / isHidden / skipFetch 等）。
        // fresh 提供的字段：git 状态、health 检测、remotes。
        var byHash = Dictionary(uniqueKeysWithValues: repositories.map { ($0.pathHash, $0) })
        for var fresh in scanned {
            if let prior = byHash[fresh.pathHash] {
                fresh = Repository(
                    id: prior.id,
                    path: fresh.path,
                    name: prior.name,
                    currentBranch: fresh.currentBranch,
                    aheadCount: fresh.aheadCount,
                    behindCount: fresh.behindCount,
                    uncommittedCount: fresh.uncommittedCount,
                    lastCommitDate: fresh.lastCommitDate,
                    lastFetchDate: prior.lastFetchDate,
                    lastFetchSuccess: prior.lastFetchSuccess,
                    remotes: fresh.remotes,
                    defaultPushRemote: prior.defaultPushRemote,
                    firstCommitHash: fresh.firstCommitHash ?? prior.firstCommitHash,
                    isHidden: prior.isHidden,
                    customTags: prior.customTags,
                    lastScanDate: Date(),
                    skipFetch: prior.skipFetch,
                    skipMainBranchWarning: prior.skipMainBranchWarning,
                    falsePositiveMarks: prior.falsePositiveMarks,
                    // Phase B: category 用户手设保留；hasReadme/hasTests 从 fresh 取最新值
                    category: prior.category,
                    hasReadme: fresh.hasReadme,
                    hasTests: fresh.hasTests,
                    // Resume Work：lastViewedDate 用户行为产物，scan 不覆盖
                    lastViewedDate: prior.lastViewedDate,
                    // 文档隐藏：用户分拣，scan 不覆盖
                    hiddenDocPaths: prior.hiddenDocPaths
                )
            }
            byHash[fresh.pathHash] = fresh
        }
        // 清掉本次扫描没出现的旧仓库（用户可能删除）
        let freshHashes = Set(scanned.map(\.pathHash))
        let merged = byHash.values.filter { freshHashes.contains($0.pathHash) }
        self.repositories = Array(merged)
        saveRepositoriesToDisk()
    }
}

// MARK: - JSON 编码器统一配置

extension JSONEncoder {
    static let pilo: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let pilo: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
