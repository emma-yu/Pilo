import Foundation

/// PushConfirmDialog 在 sheet 中跨多个阶段共享的状态。
///
/// 三个阶段：
///   - `.preflight(...)`：用户已经打开 sheet，看到要推什么；可以取消或开推
///   - `.running(...)`：git push 正在跑
///   - `.completed(report)`：成功 / 失败展示，等用户关闭 sheet
struct PushSession: Identifiable, Sendable {
    let id: UUID
    var state: State

    struct Preflight: Sendable, Hashable {
        let repoId: UUID
        let repoPath: String
        let repoName: String
        let remote: String
        let branch: String
        let willSetUpstream: Bool
        let commits: [CommitSummary]
        var findings: [ScanFinding] = []
        var guardFindings: [CommitGuardFinding] = []
        var scanSkippedByKillSwitch: Bool = false
        var bypassConfirmed: Bool = false
        /// session-scoped 忽略集合（"仅本次忽略"按钮写入；不持久化）
        var ignoredIds: Set<UUID> = []
        /// S3 Identity Sentinel —— commit author 跟 repo category 期望身份不匹配
        /// nil = 无 mismatch / 没配 pool / category=unset。Push 仍可继续，只 warning
        var identityMismatch: IdentityValidator.Mismatch? = nil
        /// 用户本次"仅本次忽略"了 identity warning
        var identityWarningIgnored: Bool = false

        // MARK: - 可见集合（过滤掉 ignoredIds）

        var visibleFindings: [ScanFinding] {
            findings.filter { !ignoredIds.contains($0.id) }
        }
        var visibleGuardFindings: [CommitGuardFinding] {
            guardFindings.filter { !ignoredIds.contains($0.id) }
        }

        // MARK: - 严重度切片

        var criticalFindings: [ScanFinding]              { visibleFindings.filter      { $0.severity == .critical } }
        var warningFindings: [ScanFinding]               { visibleFindings.filter      { $0.severity == .warning  } }
        var criticalGuardFindings: [CommitGuardFinding]  { visibleGuardFindings.filter { $0.severity == .critical } }
        var warningGuardFindings: [CommitGuardFinding]   { visibleGuardFindings.filter { $0.severity == .warning  } }

        var hasCritical: Bool {
            !criticalFindings.isEmpty || !criticalGuardFindings.isEmpty
        }
        var hasWarning: Bool {
            !warningFindings.isEmpty || !warningGuardFindings.isEmpty
        }
        var hasAnyIssue: Bool { hasCritical || hasWarning }

        var totalCriticalCount: Int {
            criticalFindings.count + criticalGuardFindings.count
        }
        var totalWarningCount: Int {
            warningFindings.count + warningGuardFindings.count
        }

        var canPushDirectly: Bool {
            !hasCritical || bypassConfirmed
        }
    }

    struct Running: Sendable, Hashable {
        let remote: String
    }

    /// `.loading` 是为了让 sheet 在 beginPushSession 拉数据期间就先弹出来，
    /// 显示 "正在准备推送..." 的 placeholder。否则点按钮到 dialog 出现之间
    /// 用户会看到几秒空白（git diff + secret scan + 每文件 git cat-file 串行）。
    struct Loading: Sendable, Hashable {
        let repoName: String
    }

    enum State: Sendable {
        case loading(Loading)
        case preflight(Preflight)
        case running(Running)
        case completed(PushReport)
    }

    init(preflight: Preflight) {
        self.id = UUID()
        self.state = .preflight(preflight)
    }

    init(loading: Loading) {
        self.id = UUID()
        self.state = .loading(loading)
    }
}
