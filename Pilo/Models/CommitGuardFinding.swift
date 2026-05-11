import Foundation

/// 文件级而非行级的风险。来自 CommitGuardScanner 对即将推送的 diff 文件清单做的检查。
///
/// 和 ScanFinding（敏感信息正则）的区别：
///   - ScanFinding 看 diff **内容**逐行匹配 → 知道"第 12 行有个 sk-…"
///   - CommitGuardFinding 看**文件本身** → 知道".env 这个文件不该 push"
///   - 两者会部分重叠（.pem 文件既触发 BEGIN PRIVATE KEY 又触发 *.pem 扩展名）——故意不去重
struct CommitGuardFinding: Identifiable, Sendable, Hashable {
    let id: UUID
    let repoId: UUID
    let filePath: String           // 相对仓库根
    let fileSize: Int64?           // bytes；nil = 删除/未知
    let kind: Kind
    let severity: FindingSeverity
    let suggestion: Suggestion?

    enum Kind: String, Sendable, Hashable {
        case envFile               // .env / .env.local / .env.production
        case privateKey            // *.pem / *.key / id_rsa / id_ed25519
        case publicKey             // *.pub
        case largeFile             // > 50MB
        case oversizeBlocked       // > 100MB (GitHub 拒绝)
        case buildArtifact         // node_modules/dist/.next 等
        case dsStore               // .DS_Store
    }

    enum Suggestion: Sendable, Hashable {
        case addToGitignore(pattern: String)
        case useLFS
        case removeFromCommits     // 文档化，不自动执行
    }

    init(repoId: UUID, filePath: String, fileSize: Int64?, kind: Kind) {
        self.id = UUID()
        self.repoId = repoId
        self.filePath = filePath
        self.fileSize = fileSize
        self.kind = kind
        self.severity = Self.severity(for: kind, size: fileSize)
        self.suggestion = Self.suggestion(for: kind, path: filePath)
    }

    // MARK: - 显示派生

    var displayKind: String {
        switch kind {
        case .envFile:           ".env 文件"
        case .privateKey:        "私钥文件"
        case .publicKey:         "SSH 公钥"
        case .largeFile:         "大文件"
        case .oversizeBlocked:   "超大文件（GitHub 100MB 上限）"
        case .buildArtifact:     "构建产物"
        case .dsStore:           ".DS_Store"
        }
    }

    var explanation: String {
        switch kind {
        case .envFile:
            ".env 通常存放 API key、数据库密码等。推送到 GitHub 后会被全世界看到。"
        case .privateKey:
            "私钥（SSH key / SSL 证书）一旦泄露相当于把家门钥匙挂在网上。"
        case .publicKey:
            "公钥不是秘密，但通常不该在源码仓库里——它泄露了你的身份。"
        case .largeFile:
            "GitHub 建议 50MB 以下；这种二进制资源更适合 Git LFS。"
        case .oversizeBlocked:
            "超过 GitHub 100MB 硬上限，push 会被远端拒绝。必须走 Git LFS。"
        case .buildArtifact:
            "构建产物应该由构建工具生成，不该进仓库——会让 diff 噪声极大。"
        case .dsStore:
            ".DS_Store 是 macOS Finder 的元数据缓存，与项目无关。"
        }
    }

    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB, .useGB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: size)
    }

    // MARK: - 严重度规则

    static func severity(for kind: Kind, size: Int64?) -> FindingSeverity {
        switch kind {
        case .envFile, .privateKey, .oversizeBlocked: .critical
        case .publicKey, .largeFile, .buildArtifact, .dsStore: .warning
        }
    }

    static func suggestion(for kind: Kind, path: String) -> Suggestion? {
        switch kind {
        case .envFile:
            return .addToGitignore(pattern: ".env\n.env.*\n!.env.example\n!.env.sample\n!.env.template")
        case .privateKey:
            return .addToGitignore(pattern: "*.pem\n*.key\nid_rsa\nid_ed25519\nid_dsa\nid_ecdsa")
        case .publicKey:
            return .addToGitignore(pattern: "*.pub")
        case .largeFile, .oversizeBlocked:
            return .useLFS
        case .buildArtifact:
            // 提取顶层目录名做模式
            let topDir = path.split(separator: "/").first.map(String.init) ?? path
            return .addToGitignore(pattern: "\(topDir)/")
        case .dsStore:
            return .addToGitignore(pattern: ".DS_Store")
        }
    }
}
