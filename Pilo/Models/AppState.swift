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
    private let fsMonitor: FSEventMonitor

    // MARK: - Push 会话

    var pushSession: PushSession?

    /// 当前消费 FSEvent 的任务；watch dirs 改变时取消重启
    private var watcherTask: Task<Void, Never>?

    // MARK: - 仓库

    var repositories: [Repository] = []
    var selectedRepoId: UUID?
    var isInitialScanComplete: Bool = false
    var scanProgressMessage: String?
    var isScanning: Bool = false

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

    // MARK: - 启动

    init() {
        let git = GitClient()
        self.gitClient = git
        self.scanner = RepoScanner(gitClient: git)
        self.pushExecutor = PushExecutor(gitClient: git)
        self.fsMonitor = FSEventMonitor()
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
    }

    func updateTone(_ newTone: Tone) {
        self.tone = newTone
        UserDefaults.standard.set(newTone.rawValue, forKey: SettingsKey.tone.rawValue)
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

    /// 由 RepoDetailView 的 Push 按钮触发：拉取要推送的 commit 列表 + 解析 upstream，
    /// 然后把 sheet 切到 preflight 状态。
    func beginPushSession(for repo: Repository) async {
        guard let branch = repo.currentBranch else { return }
        let defaultRemote = repo.defaultPushRemote
        let upstream = await gitClient.branchUpstream(repo: URL(fileURLWithPath: repo.path), branch: branch)
        let willSetUpstream = upstream == nil
        let remote = upstream?.remote ?? defaultRemote
        let upstreamBranch = upstream?.branch ?? branch
        let commits = await gitClient.pendingPushCommits(
            repo: URL(fileURLWithPath: repo.path),
            branch: upstreamBranch,
            remote: remote
        )

        let preflight = PushSession.Preflight(
            repoId: repo.id,
            repoPath: repo.path,
            repoName: repo.name,
            remote: remote,
            branch: branch,
            willSetUpstream: willSetUpstream,
            commits: commits
        )
        self.pushSession = PushSession(preflight: preflight)
    }

    /// PushConfirmDialog 的"推送"按钮调用。从 preflight → running → completed。
    func executePush() async {
        guard let session = pushSession,
              case .preflight(let pre) = session.state else { return }

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

    func dismissPushSession() {
        pushSession = nil
        // 推送后做一次轻量 rescan 校准 ahead/behind
        Task { [weak self] in
            await self?.rescan()
        }
    }

    func applyScanResult(_ scanned: [Repository]) {
        // 按 pathHash 合并：保留旧条目的 customTags / isHidden / skipFetch / skipMainBranchWarning
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
                    skipMainBranchWarning: prior.skipMainBranchWarning
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
