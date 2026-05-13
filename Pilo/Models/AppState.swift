import Foundation
import SwiftUI
import Observation
@preconcurrency import UserNotifications

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
    let dailyDigestService: DailyDigestService
    let letterComposer: LetterComposer
    let commitNotifier: CommitNotifier
    let updateChecker: UpdateChecker
    let soundPlayer: SoundPlayer
    private let fsMonitor: FSEventMonitor
    private var updateCheckTask: Task<Void, Never>?

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
        repositories
            .filter { $0.hasWork && !$0.isHidden }
            // 按 lastCommitDate 倒序：最近动过的 repo 排前面 —— 跟用户的工作记忆同步
            .sorted { ($0.lastCommitDate ?? .distantPast) > ($1.lastCommitDate ?? .distantPast) }
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

    /// 启动时一次性检测的"已安装 AI coding 工具"列表。给主面板「打开 ▾」menu 用。
    var detectedAITools: [AITool] = []

    var watchDirectories: [URL] = []

    // MARK: - 设置（镜像 UserDefaults）

    var tone: Tone = AppSettingsDefaults.tone
    var language: Language = .systemDefault

    /// S3 Identity Sentinel —— 用户配的"work/personal/experiment" 各自期望 email
    var identityPool: IdentityPool = IdentityPool(work: nil, personal: nil, experiment: nil)

    /// 信件称呼用的用户名字。空 = fallback 到 git config user.name，再 fallback 到 "朋友"
    var userDisplayName: String = ""

    /// Commit 通知开关（镜像 UserDefaults + UN center 权限实际状态合取）
    /// 启动时：UserDefaults 说 true 但系统权限被撤 → 此处也是 false（不会偷偷发通知）
    var enableCommitNotifications: Bool = false

    /// 邮局音效开关（镜像 UserDefaults）。默认 OFF —— productivity app 静音惯例
    var enableSoundEffects: Bool = false {
        didSet { soundPlayer.enabled = enableSoundEffects }
    }

    /// 通知点击 delegate（强引用 —— UN center.delegate 是 weak）
    private var notificationDelegate: CommitNotificationDelegate?

    /// S2 跨 Repo 工作日报 —— 当前刚算出的 daily digest（每次 rescan / 5min 刷一次）
    var dailyDigest: DailyDigest?
    private var dailyDigestTask: Task<Void, Never>?

    // === 每日邮局信件 ===
    /// 信件箱归档（持久化在 letters.json）
    var letterArchive: LetterArchive = .empty
    /// 当前正在阅读的信件（sheet binding）
    var readingLetter: DailyLetter?
    /// 信箱 sheet 是否打开
    var isArchiveSheetOpen: Bool = false
    private var composeTask: Task<Void, Never>?

    // === 版本通告信（独立持久化，跟 DailyLetter 互不干扰）===
    /// release-letters.json 归档
    var releaseLetterArchive: ReleaseLetterArchive = .empty
    /// 当前正在阅读的版本通告（reader sheet binding）
    var readingReleaseLetter: ReleaseLetter?

    // === 「新版本已发车」推送信 ===
    /// 当前已知可下载的新版本通告（至多 1 封；nil = 没新版本/未检查）
    var updateAvailableArchive: UpdateAvailableArchive = .empty
    /// 当前正在阅读的更新通告
    var readingUpdateLetter: UpdateAvailableLetter?

    // === Prompt 邮票本 ===
    /// 邮票本归档（持久化在 prompt-stamps.json）
    var promptStampArchive: PromptStampArchive = .empty
    /// 当前正在编辑的邮票（nil = editor sheet 关闭；非 nil 但 id 是新 UUID 表示新建）
    var editingStamp: PromptStamp?
    /// 邮票全集 sheet 是否打开
    var isStampArchiveOpen: Bool = false
    /// 邮戳 toast —— "已誊抄" 提示。nil = 不显示；自动 1.5s 后清空
    var stampToastMessage: String?
    private var stampToastTask: Task<Void, Never>?

    /// Sidebar 邮票本 widget 是否折叠（仅 toolbar capsule 可见，便签卡片隐藏）。
    /// 默认展开；用户偏好持久化到 UserDefaults。
    var isStampBookCollapsed: Bool = UserDefaults.standard.bool(forKey: "pilo.stampBook.collapsed") {
        didSet {
            UserDefaults.standard.set(isStampBookCollapsed, forKey: "pilo.stampBook.collapsed")
        }
    }

    /// Sidebar 展示用：所有钉住的邮票（按 lastUsedAt 倒序，未使用按 createdAt）。
    /// **不再硬限制 N 张** —— 用户 pin 多少都显示；grid 超 9 张时 sticky note 卡片内部 ScrollView 滑动。
    var sidebarStamps: [PromptStamp] {
        promptStampArchive.stamps
            .filter { $0.pinned }
            .sorted { a, b in
                (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
            }
    }

    /// 总邮票数（empty state 判断用）
    var totalStampCount: Int { promptStampArchive.stamps.count }
    /// 邮票本里还有多少张**未钉**的邮票 —— sidebar 不显示这部分，archive 才看得到
    var sidebarOverflowCount: Int {
        max(0, totalStampCount - sidebarStamps.count)
    }

    /// 信箱总未读数（DailyLetter + ReleaseLetter + UpdateAvailableLetter）
    var inboxUnreadCount: Int {
        let daily = letterArchive.unreadCount
        let release = releaseLetterArchive.letters.filter(\.isUnread).count
        let update = (updateAvailableArchive.current?.isUnread ?? false) ? 1 : 0
        return daily + release + update
    }
    var inboxHasUnread: Bool { inboxUnreadCount > 0 }

    /// 信箱按时间倒序排好的统一项 —— LetterArchiveView 直接遍历
    /// UpdateAvailableLetter 总排第一位（最重要的提醒，引导下载）
    var inboxItems: [InboxItem] {
        let daily = letterArchive.letters.map { InboxItem.daily($0) }
        let release = releaseLetterArchive.letters.map { InboxItem.release($0) }
        let sorted = (daily + release).sorted { $0.sortDate > $1.sortDate }
        if let update = updateAvailableArchive.current {
            return [.updateAvailable(update)] + sorted
        }
        return sorted
    }

    // MARK: - 启动

    init() {
        let git = GitClient()
        self.gitClient = git
        self.scanner = RepoScanner(gitClient: git)
        self.pushExecutor = PushExecutor(gitClient: git)
        self.secretScanner = SecretScanner()
        self.commitGuard = CommitGuardScanner()
        self.visibilityClient = GitHubVisibilityClient()
        self.dailyDigestService = DailyDigestService(gitClient: git)
        self.letterComposer = LetterComposer(gitClient: git)
        self.commitNotifier = CommitNotifier()
        self.updateChecker = UpdateChecker()
        self.soundPlayer = SoundPlayer()
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
        self.identityPool = IdentityPool.load()
        self.letterArchive = LetterStore.load()
        self.releaseLetterArchive = ReleaseLetterStore.load()
        self.updateAvailableArchive = UpdateAvailableStore.load()
        self.promptStampArchive = PromptStampStore.load()
        self.userDisplayName = UserDefaults.standard.string(forKey: SettingsKey.userDisplayName.rawValue) ?? ""
        // 邮局音效开关（默认 false）
        let soundOn = UserDefaults.standard.bool(forKey: SettingsKey.enableSoundEffects.rawValue)
        self.enableSoundEffects = soundOn
        soundPlayer.enabled = soundOn
        // 把 SoundPlayer 接到 CommitNotifier —— 通知投递成功时同步播 letterArrived
        let notifier = commitNotifier
        let player = soundPlayer
        Task { await notifier.attachSoundPlayer(player) }
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

        // 异步检测 AI 工具（spawn which 略慢，放后台）
        let tools = await Task.detached(priority: .userInitiated) {
            AIToolDetector.detect()
        }.value
        self.detectedAITools = tools

        // 用户没在 Settings 配名字 → 用 git global user.name 兜底（仅当 displayName 空）
        if userDisplayName.isEmpty {
            if let gitName = await gitClient.globalUserName() {
                self.userDisplayName = gitName
                // 不写 UserDefaults —— 让用户在 Settings 主动确认 / 改后才持久化
            }
        }

        // 安装通知点击 delegate —— 无论用户当前开没开通知都装：
        // 防御场景：用户在系统设置里把权限重开后，老通知（如果存在）也能正确路由
        installNotificationDelegate()

        // 版本通告信投递 —— 在 watch dirs / repo scan 之前跑，让用户一打开就看到
        injectNewReleaseLettersIfNeeded()

        // 「新版本已发车」推送检查 —— 异步 fire-and-forget，不阻塞 bootstrap
        // 24h 频控由 UpdateChecker 自己管，频繁启动 app 不会重复 GET
        kickoffUpdateCheck()

        // 恢复 Commit 通知偏好。注意：opt-in only —— 用户没在 Settings 主动打开过 → 永远 false
        // 即使 UserDefaults 是 true，也要再 check 系统权限是否被撤销（在 macOS 系统设置里手动关）
        await restoreCommitNotificationState()

        // 即使没有 watch dirs 也标记完成；空状态由 view 决定显示什么
        if watchDirectories.isEmpty {
            isInitialScanComplete = true
            return
        }
        await rescan()
        restartFSMonitor()
    }

    /// 安装通知 delegate —— 通知被点 → 跳到对应 repo 并打开主窗
    private func installNotificationDelegate() {
        let weakSelf = self
        let delegate = CommitNotificationDelegate { [weak weakSelf] repoId in
            guard let self = weakSelf else { return }
            // 通知 → 打开主窗 + 选中 repo（如果还在仓库列表里）
            if self.repositories.contains(where: { $0.id == repoId }) {
                self.selectRepo(repoId)
            }
        }
        self.notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    /// 启动时调用：UserDefaults 持久化的开关 ∧ 系统当前授权状态。
    /// 任一为 false → enabled 为 false（避免偷偷发通知）
    private func restoreCommitNotificationState() async {
        let userPref = UserDefaults.standard.bool(forKey: SettingsKey.enableCommitNotifications.rawValue)
        guard userPref else {
            self.enableCommitNotifications = false
            return
        }
        // 用户之前开过 —— check 系统权限是否还在
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted = settings.authorizationStatus == .authorized
                   || settings.authorizationStatus == .provisional
        if granted {
            _ = await commitNotifier.enable()
            self.enableCommitNotifications = true
        } else {
            // 用户在系统设置里关了 —— 静默降级，下次他打开 Settings 看到 toggle off 自然
            self.enableCommitNotifications = false
            UserDefaults.standard.set(false, forKey: SettingsKey.enableCommitNotifications.rawValue)
        }
    }

    /// 用户在 Settings 切音效 toggle 时调用
    func setSoundEffects(_ on: Bool) {
        enableSoundEffects = on   // didSet 会同步 SoundPlayer
        UserDefaults.standard.set(on, forKey: SettingsKey.enableSoundEffects.rawValue)
        // 切到 ON 时立刻预览一下"信件到达"音效，让用户感受到"开关确实生效了"
        if on { soundPlayer.play(.letterArrived) }
    }

    /// 用户在 Settings 切 Commit 通知 toggle 时调用。
    /// 打开 → 请求权限；权限被拒 → 同步把 state 改回 false
    /// 关闭 → 立即停 actor + 清掉 pending
    func setCommitNotifications(_ on: Bool) async {
        if on {
            let granted = await commitNotifier.enable()
            self.enableCommitNotifications = granted
            UserDefaults.standard.set(granted, forKey: SettingsKey.enableCommitNotifications.rawValue)
        } else {
            await commitNotifier.disable()
            self.enableCommitNotifications = false
            UserDefaults.standard.set(false, forKey: SettingsKey.enableCommitNotifications.rawValue)
        }
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
        // S2: 扫盘后刷新今日 digest（非阻塞）
        refreshDailyDigest()
        // 每日邮局：今天 ≥ 18:00 且没今日信 → 立即 compose 并归档
        composeTodayLetterIfNeeded()
    }

    /// S2: 刷新跨 repo 工作日报 —— 异步 detached，不阻塞 UI
    func refreshDailyDigest() {
        dailyDigestTask?.cancel()
        let repos = self.repositories
        let service = self.dailyDigestService
        dailyDigestTask = Task { [weak self] in
            let digest = await service.compute(repos: repos)
            await MainActor.run { self?.dailyDigest = digest }
        }
    }

    // MARK: - 每日邮局信件

    /// 检查并按需 compose 今日信件：
    ///   - 今天没生成过信
    ///   - 当前时间 ≥ 18:00（投递时间）OR 用户手动触发
    ///   - 有活动（commit / 草稿）
    /// 写盘后追加到 archive 头部
    func composeTodayLetterIfNeeded(forceNow: Bool = false) {
        composeTask?.cancel()
        let today = Calendar.current.startOfDay(for: Date())
        // 已有今天的信 → skip
        if letterArchive.letter(forDate: today) != nil { return }
        // 不到 18:00 且不强制 → skip
        if !forceNow && !DailyLetterScheduler.shouldDeliverImmediately(
            now: Date(),
            archive: letterArchive
        ) {
            return
        }

        let repos = self.repositories
        let composer = self.letterComposer
        let addressee = self.userDisplayName.isEmpty ? nil : self.userDisplayName
        composeTask = Task { [weak self] in
            let letter = await composer.compose(repos: repos, addressee: addressee)
            guard letter.isWorthSending else { return }
            await MainActor.run {
                guard let self else { return }
                var archive = self.letterArchive
                archive.letters.insert(letter, at: 0)
                self.letterArchive = archive
                LetterStore.save(archive)
                // 🕊️ 信件到达音
                self.soundPlayer.play(.letterArrived)
            }
        }
    }

    // MARK: - 版本通告信

    /// 启动时调用：对比 release-notes.json 跟用户上次见到的版本，
    /// 把所有「未见过」的版本生成 ReleaseLetter 写入信箱。幂等：同版本不重投。
    private func injectNewReleaseLettersIfNeeded() {
        let bundled = ReleaseNotesLoader.bundledReleases()
        guard !bundled.isEmpty else { return }

        let lastSeenKey = "lastSeenReleaseVersion"
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenKey) ?? "0.0.0"

        // 找出比 lastSeen 新的所有版本
        let newReleases = bundled.filter {
            Semver.compare($0.version, lastSeen) == .orderedDescending
        }
        guard !newReleases.isEmpty else { return }

        // 防御：archive 里如果已经有这个 version 的信，跳过（极端 case 防双发）
        let existingVersions = Set(releaseLetterArchive.letters.map(\.version))

        var archive = releaseLetterArchive
        let now = Date()
        for release in newReleases where !existingVersions.contains(release.version) {
            archive.letters.insert(
                ReleaseLetter(
                    id: UUID(),
                    version: release.version,
                    releaseDate: release.releaseDate,
                    deliveredAt: now,
                    readAt: nil,
                    title: release.title,
                    highlights: release.highlights,
                    bodyParagraphs: release.body
                ),
                at: 0
            )
        }
        releaseLetterArchive = archive
        ReleaseLetterStore.save(archive)

        // 把"已见过"标记推到最新（即便有信延迟读，下次启动也不会再投）
        if let latest = bundled.max(by: { Semver.compare($0.version, $1.version) == .orderedAscending }) {
            UserDefaults.standard.set(latest.version, forKey: lastSeenKey)
        }
    }

    // MARK: - 「新版本已发车」推送

    /// 启动 fire-and-forget 检查 —— UpdateChecker 内部有 24h 频控
    func kickoffUpdateCheck() {
        updateCheckTask?.cancel()
        let checker = updateChecker
        let currentVersion = ReleaseNotesLoader.currentAppVersion() ?? "0.0.0"
        updateCheckTask = Task { [weak self] in
            guard await checker.shouldCheckNow() else { return }
            guard let new = await checker.check(currentAppVersion: currentVersion) else { return }
            await MainActor.run {
                self?.applyUpdateAvailableLetter(new)
            }
        }
    }

    /// 检查发现新版本 → 写入信箱（覆盖已有）
    private func applyUpdateAvailableLetter(_ new: UpdateAvailableLetter) {
        // 如果当前信箱里已经是同版本，保留旧的 readAt 状态（避免反复刷成未读）
        if let existing = updateAvailableArchive.current,
           Semver.compare(existing.version, new.version) == .orderedSame {
            return
        }
        var archive = updateAvailableArchive
        archive.current = new
        updateAvailableArchive = archive
        UpdateAvailableStore.save(archive)
        // 📮 柜台铃 —— 新版本到达是仪式时刻
        soundPlayer.play(.updateArrived)
    }

    /// 用户从信箱点更新通告 → 进入 reader
    func openUpdateLetter(_ letter: UpdateAvailableLetter) {
        isArchiveSheetOpen = false
        readingUpdateLetter = letter
    }

    /// 关闭更新通告 reader → 标记已读
    func closeReadingUpdateLetter() {
        if let letter = readingUpdateLetter, letter.readAt == nil {
            markUpdateLetterRead(letter)
        }
        readingUpdateLetter = nil
    }

    /// 标记更新通告已读 + 持久化
    func markUpdateLetterRead(_ letter: UpdateAvailableLetter) {
        guard var archive = updateAvailableArchive.current.map({ _ in updateAvailableArchive }),
              archive.current?.id == letter.id else { return }
        archive.current?.readAt = Date()
        updateAvailableArchive = archive
        UpdateAvailableStore.save(archive)
    }

    /// 用户点「下载新版本」按钮 → 在浏览器打开 downloadURL
    func downloadUpdate(_ letter: UpdateAvailableLetter) {
        NSWorkspace.shared.open(letter.downloadURL)
        // 标记已读（用户已经响应了行动）
        markUpdateLetterRead(letter)
    }

    /// 用户点「以后再说」/「不感兴趣」—— 从信箱清掉这条通告
    func dismissUpdateLetter() {
        var archive = updateAvailableArchive
        archive.current = nil
        updateAvailableArchive = archive
        UpdateAvailableStore.save(archive)
        readingUpdateLetter = nil
    }

    // MARK: - 版本通告信（已升级到此版本后的回顾）

    /// 把指定版本通告标记为已读 + 持久化
    func markReleaseLetterRead(_ letter: ReleaseLetter) {
        guard let idx = releaseLetterArchive.letters.firstIndex(where: { $0.id == letter.id }) else { return }
        guard releaseLetterArchive.letters[idx].readAt == nil else { return }
        releaseLetterArchive.letters[idx].readAt = Date()
        ReleaseLetterStore.save(releaseLetterArchive)
    }

    /// 用户从信箱点版本通告 → 进入 reader
    func openReleaseLetter(_ letter: ReleaseLetter) {
        isArchiveSheetOpen = false
        readingReleaseLetter = letter
    }

    /// 关闭版本通告 reader → 标记已读
    func closeReadingReleaseLetter() {
        if let letter = readingReleaseLetter {
            markReleaseLetterRead(letter)
        }
        readingReleaseLetter = nil
    }

    /// 把指定信件标记为已读 + 持久化
    func markLetterRead(_ letter: DailyLetter) {
        guard let idx = letterArchive.letters.firstIndex(where: { $0.id == letter.id }) else { return }
        guard letterArchive.letters[idx].readAt == nil else { return }
        letterArchive.letters[idx].readAt = Date()
        LetterStore.save(letterArchive)
    }

    /// 用户在 Settings 改了"你叫什么"时调用 —— 持久化 + in-memory state
    func updateUserDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userDisplayName = trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: SettingsKey.userDisplayName.rawValue)
        } else {
            UserDefaults.standard.set(trimmed, forKey: SettingsKey.userDisplayName.rawValue)
        }
    }

    /// 用户在 PanelHeader 点信箱
    func openLetterArchive() {
        isArchiveSheetOpen = true
    }

    /// 用户在 archive 点单封信
    func openLetter(_ letter: DailyLetter) {
        isArchiveSheetOpen = false
        readingLetter = letter
    }

    /// 关闭阅读 view —— 标记已读 + 重新打开 archive
    func closeReadingLetter() {
        if let letter = readingLetter {
            markLetterRead(letter)
        }
        readingLetter = nil
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
    ///
    /// **关键 UX 设计**：先立刻 set `.loading` 让 sheet 立即弹出 placeholder dialog，
    /// 然后 async 跑各种 heavy 操作（diff / secret scan / blob size 等可能耗时几秒），
    /// 全部跑完再 transition 到 `.preflight`。
    /// 避免用户点了推送按钮后看到几秒空白窗口。
    func beginPushSession(for repo: Repository) async {
        guard let branch = repo.currentBranch else { return }
        // 1) 立刻弹 loading sheet —— UI 立即响应
        let loading = PushSession(loading: .init(repoName: repo.name))
        let sessionId = loading.id
        self.pushSession = loading

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

        // S3 Identity Sentinel：在 preflight 期间检查 commit author email
        // 跟 repo category 期望身份是否匹配。Pool 空 / category=unset → skip
        var identityMismatch: IdentityValidator.Mismatch? = nil
        if !identityPool.isEmpty && repo.category != .unset {
            let localEmail = await gitClient.localUserEmail(repo: repoURL)
            identityMismatch = IdentityValidator.validate(
                category: repo.category,
                identityPool: identityPool,
                commits: commits,
                currentLocalEmail: localEmail
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
            ignoredIds: [],
            identityMismatch: identityMismatch
        )
        // 用户可能在 loading 期间手动关 sheet（点 sheet 外）—— 这种情况 pushSession 已 nil
        // 或者重新点了别的 repo 的 push（pushSession.id 变了）。
        // 都不应该再 reopen，所以加 guard：只有 sessionId 仍是这次 loading 的才 transition。
        guard var existing = self.pushSession, existing.id == sessionId else { return }
        // **保持 id 不变**：直接 mutate state；否则 SwiftUI sheet(item:) 看到 id 变化
        // 会 dismiss + re-present，造成闪烁
        existing.state = .preflight(preflight)
        self.pushSession = existing
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

    /// History 脱钩时的"覆盖远程历史"按钮调用 —— 用 --force-with-lease 强推。
    /// 仅在 PushConfirmDialog 失败态 + historyDiverged 二次确认后允许。
    func forcePushCurrentSession() async {
        guard let session = pushSession,
              case .completed(let prevReport) = session.state,
              prevReport.outcome.isHistoryDiverged else { return }

        // 切到 running —— 鸽子起飞，循环播放"飞行中"音直到结果回来
        var s = session
        s.state = .running(.init(remote: prevReport.remote))
        pushSession = s
        soundPlayer.playLooping(.pushInFlight)

        let report = await pushExecutor.forcePush(
            repoURL: URL(fileURLWithPath: repositories.first(where: { $0.id == prevReport.repoId })?.path ?? ""),
            repoId: prevReport.repoId,
            repoName: prevReport.repoName,
            remote: prevReport.remote,
            branch: prevReport.branch,
            commitCount: prevReport.commitCount
        )

        // 推送完成 —— 先停 in-flight loop，再播抵达音 / 切 completed 态
        soundPlayer.stop(.pushInFlight)

        // 成功 → 乐观更新 aheadCount = 0
        if report.outcome.isSuccess {
            if let idx = repositories.firstIndex(where: { $0.id == prevReport.repoId }) {
                repositories[idx].aheadCount = 0
                saveRepositoriesToDisk()
            }
            soundPlayer.play(.pushSuccess)
        }

        var s2 = session
        s2.state = .completed(report)
        pushSession = s2
    }

    /// PushConfirmDialog 的"推送"按钮调用。从 preflight → running → completed。
    func executePush() async {
        guard let session = pushSession,
              case .preflight(let pre) = session.state else { return }
        // 安全闸门：critical findings 必须 bypass 才能继续。UI 应该已经禁推，这里再兜底。
        guard pre.canPushDirectly else { return }

        // 切到 running —— 鸽子起飞，循环播放"飞行中"音直到结果回来
        var s = session
        s.state = .running(.init(remote: pre.remote))
        pushSession = s
        soundPlayer.playLooping(.pushInFlight)

        let report = await pushExecutor.push(
            repoURL: URL(fileURLWithPath: pre.repoPath),
            repoId: pre.repoId,
            repoName: pre.repoName,
            remote: pre.remote,
            branch: pre.branch,
            commitCount: pre.commits.count,
            setUpstream: pre.willSetUpstream
        )

        // 推送完成 —— 先停 in-flight loop，再播抵达音 / 切 completed 态
        soundPlayer.stop(.pushInFlight)

        // 推送成功 → 该仓库 aheadCount 清零（后续 fetch 会校准；先乐观更新）
        if report.outcome.isSuccess {
            if let idx = repositories.firstIndex(where: { $0.id == pre.repoId }) {
                repositories[idx].aheadCount = 0
                saveRepositoriesToDisk()
            }
            soundPlayer.play(.pushSuccess)
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

    // MARK: - S3 Identity Sentinel

    /// 用户在 Settings 里改了 identity pool 时调用 —— 持久化 + 更新 in-memory state
    func updateIdentityPool(work: String?, personal: String?, experiment: String?) {
        let pool = IdentityPool(work: work, personal: personal, experiment: experiment)
        self.identityPool = pool
        IdentityPool.save(pool)
    }

    /// 用户在 preflight 点「一键修正 author」时调用：
    /// 把 repo 的 local git config user.email 改成 category 期望值。
    /// 注意：只修 default config，不改已 commit 的 author（避免破坏 git history）
    func fixLocalIdentity() async {
        guard let session = pushSession,
              case .preflight(let pre) = session.state,
              let mismatch = pre.identityMismatch else { return }
        let repoURL = URL(fileURLWithPath: pre.repoPath)
        _ = await gitClient.setLocalUserEmail(repo: repoURL, email: mismatch.expectedEmail)
        // 重新拉一次 identity check 让 banner 消失（用户下次 commit 起就用新 email）
        if let session2 = pushSession, case .preflight(var pre2) = session2.state {
            pre2.identityWarningIgnored = true
            var s = session2
            s.state = .preflight(pre2)
            pushSession = s
        }
    }

    /// "仅本次忽略" identity warning
    func ignoreIdentityWarningOnce() {
        guard let session = pushSession, case .preflight(var pre) = session.state else { return }
        pre.identityWarningIgnored = true
        var s = session
        s.state = .preflight(pre)
        pushSession = s
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
        case .roadmap:         return 3
        case .prd:             return 4
        case .todo:            return 5
        case .changelog:       return 6
        case .contributing:    return 7
        case .license:         return 8
        case .notes:           return 9
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
        // 防御性：用户在 running 态强关 sheet，确保 in-flight loop 不留尾音
        soundPlayer.stop(.pushInFlight)
        pushSession = nil
        // 推送后做一次轻量 rescan 校准 ahead/behind
        Task { [weak self] in
            await self?.rescan()
        }
    }

    func applyScanResult(_ scanned: [Repository]) {
        // 按 pathHash 合并：保留旧条目的用户手设字段（category / customTags / isHidden / skipFetch 等）。
        // fresh 提供的字段：git 状态、health 检测、remotes、latestCommitHash。
        var byHash = Dictionary(uniqueKeysWithValues: repositories.map { ($0.pathHash, $0) })

        // 收集 commit diff：[(repoId, repoName, repoPath, prevHash, newHash)]
        // 在循环里 build；循环外 dispatch async fetch + notify（一次性，避免 N task）
        var diffs: [CommitDiff] = []

        for var fresh in scanned {
            if let prior = byHash[fresh.pathHash] {
                // === Commit 通知：决定 baseline ===
                // prior.lastNotifiedCommitHash 没有 → 这是第一次见 latestHash（旧 state.json 升级 / 用户首次开通知）
                //   → 静默 baseline 到 fresh.latestCommitHash，不发通知
                // prior.lastNotifiedCommitHash 有 && 等于 fresh.latestCommitHash → 没新 commit，原样
                // prior.lastNotifiedCommitHash 有 && 不等于 fresh.latestCommitHash → 有新 commit，
                //   发通知 + baseline 推进
                let priorBaseline = prior.lastNotifiedCommitHash
                let newHead = fresh.latestCommitHash
                var nextBaseline: String? = priorBaseline ?? newHead

                if let prev = priorBaseline,
                   let head = newHead,
                   prev != head,
                   enableCommitNotifications {
                    diffs.append(CommitDiff(
                        repoId: prior.id,
                        repoName: prior.name,
                        repoPath: fresh.path,
                        prevHash: prev,
                        newHash: head
                    ))
                    nextBaseline = head
                } else if priorBaseline == nil {
                    // 首次 baseline —— 不发通知
                    nextBaseline = newHead
                }

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
                    hiddenDocPaths: prior.hiddenDocPaths,
                    // AI 工具配置：派生信号，每次 scan 由 fresh 覆盖
                    aiToolsDetected: fresh.aiToolsDetected,
                    // Commit 通知 baselines
                    latestCommitHash: newHead,
                    lastNotifiedCommitHash: nextBaseline
                )
            } else {
                // 全新发现的仓库 —— 静默 baseline；下次 scan 才开始算 diff
                fresh.lastNotifiedCommitHash = fresh.latestCommitHash
            }
            byHash[fresh.pathHash] = fresh
        }
        // 清掉本次扫描没出现的旧仓库（用户可能删除）
        let freshHashes = Set(scanned.map(\.pathHash))
        let merged = byHash.values.filter { freshHashes.contains($0.pathHash) }
        self.repositories = Array(merged)
        saveRepositoriesToDisk()

        // 通知 dispatch —— 异步拉 commits + enqueue
        // 必须在 saveRepositoriesToDisk 之后跑：baseline 已落盘，即便此处崩溃
        // 下次启动也不会重发通知风暴
        if !diffs.isEmpty && enableCommitNotifications {
            dispatchCommitNotifications(diffs)
        }
    }

    private struct CommitDiff: Sendable {
        let repoId: UUID
        let repoName: String
        let repoPath: String
        let prevHash: String
        let newHash: String
    }

    /// 异步：对每个 diff 拉新 commits + enqueue notifier
    /// 不阻塞 UI；失败静默（commitsBetween 可能因 rebase 失效返回空，notifier 自然 no-op）
    private func dispatchCommitNotifications(_ diffs: [CommitDiff]) {
        let gc = gitClient
        let notifier = commitNotifier
        Task.detached {
            for diff in diffs {
                let commits = await gc.commitsBetween(
                    repo: URL(fileURLWithPath: diff.repoPath),
                    from: diff.prevHash,
                    to: diff.newHash
                )
                guard !commits.isEmpty else { continue }
                await notifier.enqueue(
                    repoId: diff.repoId,
                    repoName: diff.repoName,
                    latestHash: diff.newHash,
                    commits: commits
                )
            }
        }
    }

    // MARK: - Prompt 邮票本 CRUD

    /// 添加新邮票（在 archive 顶部插入，便于刚建完就看见）
    func addPromptStamp(_ stamp: PromptStamp) {
        var archive = promptStampArchive
        archive.stamps.insert(stamp, at: 0)
        promptStampArchive = archive
        PromptStampStore.save(archive)
    }

    /// 更新现有邮票（id 匹配）
    func updatePromptStamp(_ stamp: PromptStamp) {
        guard let idx = promptStampArchive.stamps.firstIndex(where: { $0.id == stamp.id }) else { return }
        var archive = promptStampArchive
        archive.stamps[idx] = stamp
        promptStampArchive = archive
        PromptStampStore.save(archive)
    }

    /// 删除邮票
    func deletePromptStamp(_ id: UUID) {
        var archive = promptStampArchive
        archive.stamps.removeAll { $0.id == id }
        promptStampArchive = archive
        PromptStampStore.save(archive)
    }

    /// 切换钉住
    func togglePinStamp(_ id: UUID) {
        guard let idx = promptStampArchive.stamps.firstIndex(where: { $0.id == id }) else { return }
        var archive = promptStampArchive
        archive.stamps[idx].pinned.toggle()
        promptStampArchive = archive
        PromptStampStore.save(archive)
    }

    /// 用户点击邮票：复制 prompt 到剪贴板 + 更新 lastUsedAt / useCount + 播放音 + toast
    func pasteStamp(_ stamp: PromptStamp) {
        // 1. 复制到剪贴板
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stamp.body, forType: .string)

        // 2. 更新邮票元数据
        guard let idx = promptStampArchive.stamps.firstIndex(where: { $0.id == stamp.id }) else { return }
        var archive = promptStampArchive
        archive.stamps[idx].lastUsedAt = Date()
        archive.stamps[idx].useCount += 1
        promptStampArchive = archive
        PromptStampStore.save(archive)

        // 3. 邮戳音
        soundPlayer.play(.waxSealCrack)

        // 4. Toast「✓ 邮票已誊抄」—— 1.5s 后自动消失
        stampToastTask?.cancel()
        let msg = Copy.Stamps.toastCopied(stamp.title, language)
        stampToastMessage = msg
        stampToastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                guard let self else { return }
                if self.stampToastMessage == msg { self.stampToastMessage = nil }
            }
        }
    }

    // MARK: - Sheet 控制

    /// 打开新建邮票 editor —— 传 nil 表示新建
    func openStampEditor(_ stamp: PromptStamp? = nil) {
        editingStamp = stamp ?? PromptStamp(title: "", body: "", emoji: "✨")
    }

    func closeStampEditor() {
        editingStamp = nil
    }

    func openStampArchive() {
        isStampArchiveOpen = true
    }

    func closeStampArchive() {
        isStampArchiveOpen = false
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
