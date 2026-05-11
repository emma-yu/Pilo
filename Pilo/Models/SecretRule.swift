import Foundation

enum FindingSeverity: String, Codable, Sendable, Hashable {
    case critical    // 阻断 push，要 bypass 流程
    case warning     // 提示但允许推
}

/// 单条扫描规则。从 `Resources/secret-rules.json` 反序列化得到。
struct SecretRule: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let pattern: String
    let severity: FindingSeverity
    let entropyMin: Double?
    let captureGroup: Int?       // nil = 0 (整段匹配)；某些规则只关心 group 1（如 AWS secret in quotes）
    let remediation: String

    var captureGroupOrZero: Int { captureGroup ?? 0 }
}

/// 顶层规则集容器
struct SecretRuleSet: Codable, Sendable {
    let version: Int
    let lastUpdated: String
    let rules: [SecretRule]
}
