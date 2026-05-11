import Foundation

/// 对即将 push 的文件清单做"误提交防护"检查。
///
/// 关注的是**文件本身**——路径模式 + 大小，不看内容（那是 SecretScanner 的工作）。
/// 设计原则：高精确率、低误报。已知 .env.example 系列、tests/fixtures 永远不报。
actor CommitGuardScanner {

    // MARK: - 阈值

    static let largeFileThreshold: Int64    = 50 * 1024 * 1024     // 50 MB
    static let oversizeThreshold: Int64     = 100 * 1024 * 1024    // 100 MB (GitHub 上限)

    // MARK: - 路径规则

    /// .env 系列：阻断
    static let envBlockedNames: Set<String> = [
        ".env", ".env.local", ".env.production", ".env.development",
        ".env.staging", ".env.test", ".env.prod", ".env.dev",
    ]

    /// 这些虽然以 .env 开头但是显式占位文件，永远不报
    static let envAllowSuffixes: [String] = [
        ".env.example", ".env.sample", ".env.template",
        ".env.dist", ".env.defaults", ".env.shared",
    ]

    /// 私钥 / 证书：阻断
    static let privateKeySuffixes: [String] = [".pem", ".key", ".pfx", ".p12"]
    static let privateKeyExactNames: Set<String> = [
        "id_rsa", "id_ed25519", "id_dsa", "id_ecdsa",
    ]

    /// 公钥：warning
    static let publicKeySuffixes: [String] = [".pub"]

    /// 构建产物目录：warning
    static let buildArtifactDirs: Set<String> = [
        "node_modules", "__pycache__", ".next", ".nuxt",
        "dist", "build", "out", "target", "DerivedData", "Pods",
    ]

    // MARK: - 入口

    func scan(
        changedFiles: [(path: String, status: Character)],
        sizeFor: @Sendable (String) async -> Int64?,
        repoId: UUID
    ) async -> [CommitGuardFinding] {

        var findings: [CommitGuardFinding] = []

        for (path, status) in changedFiles {
            // 删除的文件不检查（删 .env 是修复，不是问题）
            if status == "D" { continue }

            let basename = (path as NSString).lastPathComponent

            // 显式安全占位 → 一律跳过
            if Self.envAllowSuffixes.contains(where: { basename.hasSuffix($0) || basename == String($0.dropFirst()) }) {
                continue
            }

            // 1) .env
            if Self.envBlockedNames.contains(basename) || (basename.hasPrefix(".env.") && !Self.envAllowSuffixes.contains(where: { basename.hasSuffix($0) })) {
                let size = await sizeFor(path)
                findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .envFile))
                continue
            }

            // 2) 私钥（精确名 + 后缀）
            if Self.privateKeyExactNames.contains(basename) ||
               Self.privateKeySuffixes.contains(where: { basename.hasSuffix($0) }) {
                let size = await sizeFor(path)
                findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .privateKey))
                continue
            }

            // 3) 公钥
            if Self.publicKeySuffixes.contains(where: { basename.hasSuffix($0) }) {
                let size = await sizeFor(path)
                findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .publicKey))
                continue
            }

            // 4) 构建产物目录（任何路径片段命中）
            let components = path.split(separator: "/").map(String.init)
            if components.contains(where: { Self.buildArtifactDirs.contains($0) }) {
                let size = await sizeFor(path)
                findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .buildArtifact))
                continue
            }

            // 5) .DS_Store
            if basename == ".DS_Store" {
                let size = await sizeFor(path)
                findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .dsStore))
                continue
            }

            // 6) 大文件 / 超大文件
            if let size = await sizeFor(path) {
                if size > Self.oversizeThreshold {
                    findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .oversizeBlocked))
                } else if size > Self.largeFileThreshold {
                    findings.append(CommitGuardFinding(repoId: repoId, filePath: path, fileSize: size, kind: .largeFile))
                }
            }
        }

        return findings
    }
}
