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

    enum State: Sendable {
        case preflight(Preflight)
        case running(Running)
        case completed(PushReport)
    }

    init(preflight: Preflight) {
        self.id = UUID()
        self.state = .preflight(preflight)
    }
}
