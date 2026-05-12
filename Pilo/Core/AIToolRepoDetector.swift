import Foundation

/// 检测一个仓库里有哪些 AI 工具的"配置印记"。
///
/// **跟 `AIToolDetector` 区别**：
///   - `AIToolDetector` 检测用户**机器全局**安装的 AI tool（`which cursor` 等）
///   - 本 detector 检测**单个仓库根目录**有没有 AI 工具的 config 文件 / 目录
///
/// 这是 v2 commit-attribution 困境的诚实答案：commit 级 attribution 难（Cursor /
/// Continue inline 不进 git），但**配置文件不会说谎** —— 仓库里有 `.cursorrules`
/// 就是 Cursor 配置过；有 `CLAUDE.md` 就是 Claude Code 配置过。
///
/// 设计原则：
///   - **诚实**：返回的 Set 表示"配置过"（Configured for），不表示"维护方"
///   - **快**：只做 FileManager.fileExists + 单层 contentsOfDirectory
///   - **保守**：只匹配 unambiguous 信号（每个工具的标志性文件名）；
///     不去猜测「instructions.md」「rules.md」这种通用名字
///   - **大小写不敏感**：macOS 默认 case-insensitive 但 APFS case-sensitive 卷
///     也要稳定工作
enum AIToolRepoDetector {

    /// 主入口：扫仓库根，返回检测到的 AI 工具集合。
    /// 失败（路径不存在 / 没权限）→ 返回空集合。
    static func detect(repoPath: String) -> Set<AITool> {
        var found: Set<AITool> = []
        let root = URL(fileURLWithPath: repoPath)
        let fm = FileManager.default

        // 提前拉根目录文件清单一次，避免每个规则跑 contentsOfDirectory
        let rootEntries: [String] = (try? fm.contentsOfDirectory(atPath: root.path))?
            .map { $0 } ?? []
        let rootLowerNames: Set<String> = Set(rootEntries.map { $0.lowercased() })

        // Claude Code: CLAUDE.md OR .claude/
        if rootLowerNames.contains("claude.md")
        || isDirectory(at: root.appendingPathComponent(".claude"), fm: fm) {
            found.insert(.claudeCode)
        }

        // Cursor: .cursorrules OR .cursor/ OR 根目录任一 *.mdc
        if rootLowerNames.contains(".cursorrules")
        || isDirectory(at: root.appendingPathComponent(".cursor"), fm: fm)
        || rootEntries.contains(where: { $0.lowercased().hasSuffix(".mdc") }) {
            found.insert(.cursor)
        }

        // Codex: AGENTS.md OR codex.md
        if rootLowerNames.contains("agents.md")
        || rootLowerNames.contains("codex.md") {
            found.insert(.codex)
        }

        // Windsurf: .windsurfrules OR .windsurf/
        if rootLowerNames.contains(".windsurfrules")
        || isDirectory(at: root.appendingPathComponent(".windsurf"), fm: fm) {
            found.insert(.windsurf)
        }

        // Aider: CONVENTIONS.md OR 根目录任一 .aider.* 文件
        if rootLowerNames.contains("conventions.md")
        || rootEntries.contains(where: { $0.lowercased().hasPrefix(".aider.") }) {
            found.insert(.aider)
        }

        // Gemini: GEMINI.md OR .gemini/
        if rootLowerNames.contains("gemini.md")
        || isDirectory(at: root.appendingPathComponent(".gemini"), fm: fm) {
            found.insert(.gemini)
        }

        return found
    }

    /// 验证 URL 指向一个 directory（不是 file，也不是不存在）。
    private static func isDirectory(at url: URL, fm: FileManager) -> Bool {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        return isDir.boolValue
    }
}
