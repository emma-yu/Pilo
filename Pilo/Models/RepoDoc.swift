import Foundation

/// 项目文档面板用：一份被 Pilo 识别为"项目文档"的文件。
/// 由 `RepoDocsIndexer` 扫仓库根 + docs/ 一级目录得到。
struct RepoDoc: Hashable, Sendable, Identifiable {
    enum Kind: String, Sendable {
        case readme         // README.*
        case changelog      // CHANGELOG.*
        case todo           // TODO.* / ROADMAP.*
        case prd            // PRD.* / REQUIREMENTS.*
        case architecture   // ARCHITECTURE.* / DESIGN.* / IMPLEMENTATION.*
        case contributing   // CONTRIBUTING.* / CODE_OF_CONDUCT.* / SECURITY.*
        case license        // LICENSE / COPYING / AUTHORS / NOTICE
        case notes          // NOTES.* / IDEAS.*
        case aiInstructions // CLAUDE.md / AGENTS.md / CURSOR.md / .cursorrules / AI.md
        case generic        // 其他 .md（根级或子目录）
    }

    let kind: Kind
    /// 相对仓库根的路径（如 `README.md` 或 `docs/architecture.md`）。
    let relativePath: String
    /// 文件名（去掉路径）。
    let name: String
    /// 文件字节数。
    let sizeBytes: Int
    /// 最后修改时间。
    let modifiedAt: Date

    var id: String { relativePath }

    /// UI 显示用：人类可读的大小（"12 KB" / "1.2 MB"）。
    var displaySize: String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(sizeBytes))
    }
}
