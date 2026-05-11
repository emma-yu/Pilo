import Foundation

/// 一次扫描发现的单条潜在敏感信息。
///
/// **安全设计**：
///   - `maskedPreview` 是面向用户的显示串（前 4 字 + ... + 后 4 字），永远不展示完整 token
///   - `captureHash` = SHA256(captured token)，用于未来识别"是不是同一个秘密"
///   - 完整匹配文本 **从不持久化、不进日志**——只在 scanner 内存里短暂存在
struct ScanFinding: Identifiable, Sendable, Hashable {
    let id: UUID
    let repoId: UUID
    let filePath: String           // 相对仓库根
    let lineNumber: Int            // 在新版本（HEAD 侧）的行号
    let ruleId: String
    let ruleName: String
    let severity: FindingSeverity
    let maskedPreview: String      // 安全展示串
    let captureHash: String        // SHA256(token) 给 FP mark 用
    let lineSnippet: String        // 当前行（也做了 mask）
    let remediationHint: String

    init(
        repoId: UUID,
        filePath: String,
        lineNumber: Int,
        rule: SecretRule,
        capturedToken: String,
        rawLine: String
    ) {
        self.id = UUID()
        self.repoId = repoId
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.ruleId = rule.id
        self.ruleName = rule.name
        self.severity = rule.severity
        self.maskedPreview = Self.mask(capturedToken)
        self.captureHash = Self.hash(capturedToken)
        self.lineSnippet = Self.maskLine(rawLine, token: capturedToken)
        self.remediationHint = rule.remediation
    }

    /// 用于 SwiftUI ID 稳定性（同一行 / 同一规则 / 同一 hash 视为同一 finding）
    var stableKey: String { "\(filePath):\(lineNumber):\(ruleId):\(captureHash.prefix(12))" }

    // MARK: - 掩码工具

    static func mask(_ token: String) -> String {
        guard token.count > 12 else {
            // 太短，直接全部用 *
            return String(repeating: "*", count: token.count)
        }
        let head = token.prefix(4)
        let tail = token.suffix(4)
        return "\(head)…\(tail)"
    }

    static func maskLine(_ line: String, token: String) -> String {
        let trimmed = String(line.prefix(160))
        return trimmed.replacingOccurrences(of: token, with: mask(token))
    }

    private static func hash(_ token: String) -> String {
        // 不引入 CryptoKit 单独依赖；Repository 已有 SHA256 helper，复用就行
        return Repository.hash(path: token)
    }
}
