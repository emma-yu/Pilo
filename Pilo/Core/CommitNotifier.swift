import Foundation
import UserNotifications

/// 小邮局的"新邮件提醒"。
///
/// 设计原则（按用户优先）：
///   1. **默认 OFF**：opt-in，避免首次使用就被通知轰炸
///   2. **60s 合并窗口**：同一 repo 在 60 秒内的连续 commit 合并成一条
///      —— `git rebase -i` / 连续多次 commit 不会刷屏
///   3. **首次扫盘静默**：首次见到一个仓库时只 baseline，不发通知
///      —— 避免 onboarding 后立刻被几十个老仓库的 HEAD 通知淹没
///   4. **postal 文案**：标题用邮局语，不用 "New commit detected"
///   5. **点通知 → 跳到那个 repo**：把 repoId 塞进 userInfo
///
/// 不做什么：
///   - 不做"推送提醒"（用户主动 push 不需要通知）
///   - 不做"远端有新 commit"（用户没拉，他不关心）
///   - 不放系统通知的 `content.sound`（macOS 默认"叮"跟邮局风格不搭）
///     —— 改在投递时 Pilo 内部播 `letterArrived`（信件落地音），同期视觉/听觉反馈
actor CommitNotifier {

    // MARK: - 状态

    /// 是否启用（镜像 UserDefaults，主入口由 AppState.setCommitNotifications 控制）
    private(set) var enabled: Bool = false

    /// 60 秒合并窗口：repoId → 当前正在攒的 pending commits
    /// key 命中 → 不立即发，等窗口结束统一发
    private struct PendingBatch {
        var commits: [CommitSummary]
        let repoName: String
        let latestHash: String        // baseline 推进到这里
        let startedAt: Date
    }
    private var pendingByRepo: [UUID: PendingBatch] = [:]
    /// 每个 repo 的 flush task —— 60s 后统一发
    private var flushTasks: [UUID: Task<Void, Never>] = [:]

    /// 合并窗口（秒）。可测试时覆盖
    let coalesceWindow: TimeInterval

    /// 测试钩子：true 时不真的调 UN center（避免单元测试触发系统弹窗）
    private let dryRun: Bool

    /// 测试用：拦截 deliverNow 实际发送的 payload，便于断言
    private(set) var deliveredForTest: [(repoId: UUID, body: String)] = []

    /// 邮局音效播放器 —— 通知投递时同步播 letterArrived（跟信箱新信件同一个音）。
    /// SoundPlayer 是 @MainActor，跨 actor 调用走 `await soundPlayer?.play(...)`
    /// nil = 测试 / dryRun 时不传，无音
    private weak var soundPlayer: SoundPlayer?

    init(coalesceWindow: TimeInterval = 60, dryRun: Bool = false) {
        self.coalesceWindow = coalesceWindow
        self.dryRun = dryRun
    }

    /// 注入 SoundPlayer —— AppState 初始化完两者后 wire 起来
    func attachSoundPlayer(_ player: SoundPlayer) {
        self.soundPlayer = player
    }

    // MARK: - 开关

    /// 用户在 Settings 打开通知：返回是否拿到权限
    /// - 失败/拒绝 → false，调用方应同步回写 UserDefaults
    func enable() async -> Bool {
        if dryRun { enabled = true; return true }
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            // 只要 .alert + .badge —— 不要 sound（commit 频繁会很吵）
            granted = try await center.requestAuthorization(options: [.alert, .badge])
        } catch {
            granted = false
        }
        enabled = granted
        return granted
    }

    /// 用户在 Settings 关闭通知：清理 pending + 移除 delivered
    func disable() {
        enabled = false
        for (_, task) in flushTasks { task.cancel() }
        flushTasks.removeAll()
        pendingByRepo.removeAll()
        if !dryRun {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    // MARK: - 核心：扫盘后的 diff 入口

    /// AppState.applyScanResult diff 完后调用。
    /// commits 已经是"上次 baseline 到 latestHash 之间"的新 commits（按时间倒序）。
    /// repo 此时还没被替换成 fresh —— caller 自己负责 baseline 推进（把 lastNotifiedCommitHash 设成 latestHash）。
    ///
    /// 内部逻辑：
    ///   - enabled = false → no-op
    ///   - commits 空 → no-op
    ///   - 命中 pending → 合并，重置 flush task；不立即发
    ///   - 新增 pending → 起 60s flush 任务
    func enqueue(
        repoId: UUID,
        repoName: String,
        latestHash: String,
        commits: [CommitSummary]
    ) {
        guard enabled, !commits.isEmpty else { return }

        // 已有 pending → 合并（新 commits 在前；不去重，window 内 commits 不会重复）
        if var existing = pendingByRepo[repoId] {
            existing.commits = commits + existing.commits
            // baseline 推进到最新；后续 commits 还来 → 再合并即可
            pendingByRepo[repoId] = PendingBatch(
                commits: existing.commits,
                repoName: repoName,
                latestHash: latestHash,
                startedAt: existing.startedAt   // 保留首条到达时间
            )
        } else {
            pendingByRepo[repoId] = PendingBatch(
                commits: commits,
                repoName: repoName,
                latestHash: latestHash,
                startedAt: Date()
            )
        }

        // 重起 flush task —— 让"连续 commit"始终往后顺延 60s（debounce 风格）
        // 注意：这是 debounce 而非 fixed window —— 用户 hot path 写代码 commit 不停时，
        // 通知只在停下来 60s 后发一次，不会每分钟叮一次
        flushTasks[repoId]?.cancel()
        let window = coalesceWindow
        flushTasks[repoId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.flush(repoId: repoId)
        }
    }

    /// flush task 醒来时调用 —— 把 pending 真的发出去
    private func flush(repoId: UUID) async {
        guard let batch = pendingByRepo.removeValue(forKey: repoId) else { return }
        flushTasks.removeValue(forKey: repoId)
        await deliverNow(
            repoId: repoId,
            repoName: batch.repoName,
            commits: batch.commits
        )
    }

    /// 直接发 —— 用于测试或确实想立即触发的场景
    private func deliverNow(repoId: UUID, repoName: String, commits: [CommitSummary]) async {
        let body = Self.bodyText(commits: commits)
        deliveredForTest.append((repoId, body))
        guard !dryRun else { return }

        let content = UNMutableNotificationContent()
        content.title = Self.titleText(count: commits.count, repoName: repoName)
        content.body = body
        //
        // **真相 (P18)**: 不要设 `interruptionLevel`。
        //
        // macOS Sequoia (15.x) 对没有 `com.apple.developer.usernotifications.time-sensitive`
        // entitlement 的 app 设 `.timeSensitive` 时，**静默降级到 `.passive`**
        // （不是 .active！），结果是：通知只进 Notification Center，**banner 不弹**。
        //
        // 直接证据来自 usernoted log:
        //   "Reducing interruption level from .timeSensitive
        //    for notification from dev.pilo.Pilo - missing authorization"
        //   ... canDisplayWhileCenterIsClosed: false
        //   ... windowOnScreenRefresh, rootViewModel is empty
        //
        // 不设 `interruptionLevel` → 默认 `.active` → banner 正常弹。这是 P8
        // 之前的最初行为（最初 commit b749c29 也没设）。
        //
        // 不放 `content.sound` —— macOS 系统"叮"跟邮局风格不搭，我们在 add 成功后
        // Pilo 内部播 letterArrived 邮局音
        content.relevanceScore = 0.8
        content.userInfo = [
            "kind": "commit",
            "repoId": repoId.uuidString,
            "commitCount": commits.count
        ]
        // identifier 用 repoId —— 同一 repo 的新通知会替换旧的（避免堆几十条）。
        // **不要**在 add 前 removeDeliveredNotifications：P15 曾这么做，怀疑引入
        // banner 抑制的副作用，P17 移除。让 macOS 自己处理替换语义。
        let req = UNNotificationRequest(
            identifier: "commit.\(repoId.uuidString)",
            content: content,
            trigger: nil    // 立即投递
        )
        do {
            try await UNUserNotificationCenter.current().add(req)
            // 投递成功 → Pilo 内部播 letterArrived（跟信箱新信件同一个音），
            // 跟 macOS 通知 banner 同步，提供"邮局感"听觉反馈
            if let player = soundPlayer {
                await player.play(.letterArrived)
            }
        } catch {
            // 不 silent —— 留 console 痕迹便于调试（P12 引入）
            print("[CommitNotifier] notification delivery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 文案（postal aesthetic）

    /// 标题：1 条 "X 仓库 · 一条新消息"；多条 "X 仓库 · 3 条新消息"
    ///
    /// **诚实文案**：commit 通知不进 Pilo 信箱（信箱只装 daily letter / release / update letter），
    /// 它就是个"路过看一眼"的系统消息，所以用「新消息」而非「新邮件」避免跟信箱混淆。
    /// 通知文案**永远中文为主**，因为 macOS 通知中心宽度有限，混用 lang 太啰嗦
    static func titleText(count: Int, repoName: String) -> String {
        if count == 1 {
            return "\(repoName) · 一条新消息"
        }
        return "\(repoName) · \(count) 条新消息"
    }

    /// body：用第一封 commit 的 subject + （多于一封时）"…等 N 封"
    /// 不展示 hash —— 通知里看 hash 没用
    static func bodyText(commits: [CommitSummary]) -> String {
        guard let first = commits.first else { return "" }
        // commit subject 太长会被系统截断；先 trim
        let subject = first.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if commits.count == 1 {
            return subject
        }
        return "\(subject)（等 \(commits.count) 封）"
    }

    // MARK: - 测试 / debug

    /// 单测用：当前 pending 状态
    var pendingCountForTest: Int { pendingByRepo.count }
    /// 单测用：某 repo pending 的 commit 数
    func pendingCommits(repoId: UUID) -> Int {
        pendingByRepo[repoId]?.commits.count ?? 0
    }
    /// 单测用：立即把 pending 全部 flush —— 不等 60s
    func flushAllForTest() async {
        let ids = Array(pendingByRepo.keys)
        for id in ids {
            flushTasks[id]?.cancel()
            flushTasks.removeValue(forKey: id)
            await flush(repoId: id)
        }
    }
}
