import Foundation

/// 扫描即将推送的 diff，找出可能的敏感信息。
///
/// 关键设计：
///   - 规则集从 bundle 的 `secret-rules.json` 一次性加载，NSRegularExpression 编译后缓存
///   - 单条规则可选 entropyMin（Shannon 熵阈值），用于过滤一眼假的占位串（如 "test1234..."）
///   - 跳过明显的样例文件：`.env.example`、`.env.sample` 等
///   - 输出按 FalsePositiveMark 过滤
///   - **完整 token 永不离开本 actor**——给上层的 ScanFinding 已经掩码
actor SecretScanner {

    /// 路径包含这些后缀/片段时直接跳过整个文件
    static let skipFilePatterns: [String] = [
        ".env.example", ".env.sample", ".env.template", ".env.dist", ".env.test.example",
        "/__fixtures__/", "/fixtures/", "/test/snapshots/", "/spec/snapshots/",
    ]

    private(set) var rules: [SecretRule]
    private var compiled: [String: NSRegularExpression]   // ruleId → regex

    /// 初始化时从 bundle 加载规则集。
    /// 用 static helper 让 init 不需要触碰 actor-isolated 状态——Swift 6 严格并发要求。
    init() {
        let loaded = Self.loadRulesFromBundle()
        self.rules = loaded.rules
        self.compiled = loaded.compiled
    }

    private static func loadRulesFromBundle() -> (rules: [SecretRule], compiled: [String: NSRegularExpression]) {
        // 用 Bundle(for: SecretScanner.self) 而非 Bundle.main：
        // 单元测试里 Bundle.main 是 test runner，找不到 app 资源；Bundle(for:) 始终
        // 找到包含本类的 bundle，无论运行上下文是 app 还是 test。
        let bundle = Bundle(for: SecretScanner.self)
        guard let url = bundle.url(forResource: "secret-rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let set = try? JSONDecoder().decode(SecretRuleSet.self, from: data)
        else {
            return ([], [:])
        }
        var compiled: [String: NSRegularExpression] = [:]
        for rule in set.rules {
            if let re = try? NSRegularExpression(pattern: rule.pattern, options: []) {
                compiled[rule.id] = re
            }
        }
        return (set.rules, compiled)
    }

    // MARK: - 公开 API

    /// 扫描一组 DiffLine（来自 DiffParser）。
    /// 已根据 falsePositiveMarks 过滤；剩下的是真正需要展示给用户的 findings。
    func scan(
        diffLines: [DiffLine],
        repoId: UUID,
        falsePositiveMarks: [FalsePositiveMark]
    ) async -> [ScanFinding] {
        var findings: [ScanFinding] = []

        for line in diffLines {
            if Self.shouldSkipFile(path: line.filePath) { continue }

            for rule in rules {
                guard let regex = compiled[rule.id] else { continue }
                let ns = line.content as NSString
                let range = NSRange(location: 0, length: ns.length)
                let matches = regex.matches(in: line.content, options: [], range: range)
                for m in matches {
                    let groupIdx = rule.captureGroupOrZero
                    guard groupIdx < m.numberOfRanges else { continue }
                    let captureRange = m.range(at: groupIdx)
                    guard captureRange.location != NSNotFound else { continue }
                    let token = ns.substring(with: captureRange)
                    if token.isEmpty { continue }

                    // 熵校验（如果规则要求）
                    if let minE = rule.entropyMin, Self.shannonEntropy(token) < minE {
                        continue
                    }

                    let finding = ScanFinding(
                        repoId: repoId,
                        filePath: line.filePath,
                        lineNumber: line.newLineNumber,
                        rule: rule,
                        capturedToken: token,
                        rawLine: line.content
                    )

                    // 误报标记过滤
                    if falsePositiveMarks.contains(where: { $0.matches(finding) }) {
                        continue
                    }

                    findings.append(finding)
                }
            }
        }

        // 去重（同一规则同一 hash 同一文件同一行）
        var seen = Set<String>()
        var deduped: [ScanFinding] = []
        for f in findings {
            if seen.insert(f.stableKey).inserted {
                deduped.append(f)
            }
        }
        return deduped
    }

    /// 查找 rule by id（UI 需要 remediation 文本时用）
    func rule(id: String) -> SecretRule? {
        rules.first { $0.id == id }
    }

    // MARK: - 静态辅助

    static func shouldSkipFile(path: String) -> Bool {
        for p in skipFilePatterns where path.contains(p) { return true }
        return false
    }

    /// Shannon 熵（bits per char）。
    /// - 全字符均匀分布的随机串：~6.0（ASCII 字母 + 数字 + 符号）
    /// - 真实 API key（base64 / hex）：通常 ≥ 4.0
    /// - 占位串 "aaaaaaa" 或 "test12345"：< 3.0
    static func shannonEntropy(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var freq: [Character: Int] = [:]
        for ch in s {
            freq[ch, default: 0] += 1
        }
        let total = Double(s.count)
        var entropy = 0.0
        for n in freq.values {
            let p = Double(n) / total
            entropy -= p * log2(p)
        }
        return entropy
    }
}
