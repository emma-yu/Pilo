import Foundation

/// 用户在某个 finding 上点了"标记为误报"后落盘的记录。
/// 下次扫描时按 (repoId, ruleId, scope) 匹配，命中则跳过此 finding。
///
/// v0.1 实现两档范围（PRD §7.3 三档去掉"类似路径"，glob 体验留 v0.2）：
///   - thisFileOnly: 限本文件 + 同一 captureHash
///   - thisRule: 整个仓库都不再扫这条规则
struct FalsePositiveMark: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let ruleId: String
    let scope: Scope
    let filePath: String?       // 仅 .thisFileOnly 用
    let captureHash: String?    // 仅 .thisFileOnly 用——精确匹配同一 token
    let markedAt: Date

    enum Scope: String, Codable, Sendable, Hashable {
        case thisFileOnly
        case thisRule
    }

    init(rule: SecretRule, scope: Scope, finding: ScanFinding) {
        self.id = UUID()
        self.ruleId = rule.id
        self.scope = scope
        switch scope {
        case .thisFileOnly:
            self.filePath = finding.filePath
            self.captureHash = finding.captureHash
        case .thisRule:
            self.filePath = nil
            self.captureHash = nil
        }
        self.markedAt = Date()
    }

    /// 给定的 finding 是否被本标记覆盖？
    func matches(_ finding: ScanFinding) -> Bool {
        guard ruleId == finding.ruleId else { return false }
        switch scope {
        case .thisRule:
            return true
        case .thisFileOnly:
            return filePath == finding.filePath && captureHash == finding.captureHash
        }
    }
}
