import Foundation

/// 检测今天有哪些 AI 工具被你使用过 + 用了多少次。
///
/// **Pilo 在 AI 生态独特的位置**：能横跨看所有 AI 工具的"工作痕迹"。
/// 这个 detector 给 daily letter 提供「今日邮局合作社」section 的数据。
///
/// **隐私边界**（重要）：
///   - 仅 `FileManager.attributesOfItem(atPath:)[.modificationDate]`
///   - 仅 `FileManager.contentsOfDirectory(at:)`
///   - **绝不读文件内容**（不 `Data(contentsOf:)`, 不 `String(contentsOf:)`）
///   - 不发送任何数据到任何地方
///
/// **路径漂移**：AI 工具升级会改路径。每个路径定义为常量便于一行替换；
/// 找不到的路径独立 try/catch → 该工具 count=0 → 不进结果数组。
actor AICompanionDetector {

    // MARK: - 已知 AI 工具数据目录（macOS）
    // Verified on user's machine as of 2026-05-13.
    // 如果某 AI 工具升级改路径，改这里一行即可。

    /// Claude Code conversation 文件：`~/.claude/projects/<repo-hash>/<conv>.jsonl`
    private static let claudeRoot = "Library/../.claude/projects"   // 通过 home + ".claude" 实际拼

    /// Cursor workspace storage: `~/Library/Application Support/Cursor/User/workspaceStorage/<hash>/`
    private static let cursorRel  = "Library/Application Support/Cursor/User/workspaceStorage"

    /// Codex CLI: `~/.codex/sessions/` 或 `~/.codex/conversations/`（path 可能漂移）
    /// 先扫 sessions，再 fallback 整个 .codex
    private static let codexSessions = ".codex/sessions"
    private static let codexFallback = ".codex"

    /// Gemini Code Assist (Antigravity): `~/.gemini/antigravity/`
    private static let geminiRel  = ".gemini/antigravity"

    /// Windsurf: `~/Library/Application Support/Windsurf/User/workspaceStorage`
    private static let windsurfRel = "Library/Application Support/Windsurf/User/workspaceStorage"

    // MARK: - 主入口

    /// 扫所有 AI 工具，返回今天活跃的 companion 列表
    /// - Parameter date: 哪一天的活动（默认今天）
    /// - Parameter repos: 项目仓库列表 —— 用来扫各 repo 内的 .aider.chat.history.md (Aider)
    /// - Returns: 仅包含 count > 0 的 tool；按 count 倒序
    func detectActivity(repos: [Repository], date: Date = Date()) -> [AICompanionSummary] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let home = FileManager.default.homeDirectoryForCurrentUser

        var results: [AICompanionSummary] = []

        // Claude Code: count today-touched .jsonl files under ~/.claude/projects/
        if let count = countRecentFiles(
            in: home.appendingPathComponent(".claude/projects"),
            since: startOfDay,
            extensionFilter: "jsonl",
            recurseOneLevel: true
        ), count > 0 {
            results.append(.init(tool: .claudeCode, activityCount: count))
        }

        // Cursor: count today-touched workspace subdirs
        if let count = countRecentSubdirs(
            in: home.appendingPathComponent(Self.cursorRel),
            since: startOfDay
        ), count > 0 {
            results.append(.init(tool: .cursor, activityCount: count))
        }

        // Codex: 先 sessions/，找不到 fallback 整个 .codex
        if let count = countRecentFiles(
            in: home.appendingPathComponent(Self.codexSessions),
            since: startOfDay,
            extensionFilter: nil,
            recurseOneLevel: true
        ), count > 0 {
            results.append(.init(tool: .codex, activityCount: count))
        } else if let count = countRecentFiles(
            in: home.appendingPathComponent(Self.codexFallback),
            since: startOfDay,
            extensionFilter: nil,
            recurseOneLevel: false
        ), count > 0 {
            results.append(.init(tool: .codex, activityCount: count))
        }

        // Gemini: count today-touched anything in antigravity/
        if let count = countRecentFiles(
            in: home.appendingPathComponent(Self.geminiRel),
            since: startOfDay,
            extensionFilter: nil,
            recurseOneLevel: true
        ), count > 0 {
            results.append(.init(tool: .gemini, activityCount: count))
        }

        // Windsurf: workspace subdirs touched today
        if let count = countRecentSubdirs(
            in: home.appendingPathComponent(Self.windsurfRel),
            since: startOfDay
        ), count > 0 {
            results.append(.init(tool: .windsurf, activityCount: count))
        }

        // Aider: 跨 watch repos 扫 .aider.chat.history.md mtime
        let aiderRepos = repos.filter { repo in
            let url = URL(fileURLWithPath: repo.path)
                .appendingPathComponent(".aider.chat.history.md")
            return fileModified(url, since: startOfDay)
        }
        if !aiderRepos.isEmpty {
            results.append(.init(tool: .aider, activityCount: aiderRepos.count))
        }

        // 按活跃度倒序 —— letter 渲染时 stable
        return results.sorted { $0.activityCount > $1.activityCount }
    }

    // MARK: - 文件扫描 helpers（仅 metadata，绝不读内容）

    /// 单文件 mtime 是否 ≥ since
    private func fileModified(_ url: URL, since: Date) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date else { return false }
        return mtime >= since
    }

    /// 目录里直接 children + 可选 recurse 一层；统计 mtime ≥ since 的文件数
    /// extensionFilter == nil 表示不过滤扩展名
    private func countRecentFiles(
        in dir: URL,
        since: Date,
        extensionFilter: String?,
        recurseOneLevel: Bool
    ) -> Int? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return nil }

        var count = 0
        guard let children = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            let isDir = values?.isDirectory ?? false
            if isDir {
                if !recurseOneLevel { continue }
                // 递归一层
                if let nested = try? fm.contentsOfDirectory(
                    at: child,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for f in nested {
                        let v = try? f.resourceValues(forKeys: [.contentModificationDateKey])
                        guard let mtime = v?.contentModificationDate, mtime >= since else { continue }
                        if let ext = extensionFilter, f.pathExtension.lowercased() != ext.lowercased() { continue }
                        count += 1
                    }
                }
            } else {
                guard let mtime = values?.contentModificationDate, mtime >= since else { continue }
                if let ext = extensionFilter, child.pathExtension.lowercased() != ext.lowercased() { continue }
                count += 1
            }
        }
        return count
    }

    /// 子目录里有多少个直接子目录今天 mtime（用于 Cursor / Windsurf workspace dirs）
    private func countRecentSubdirs(in dir: URL, since: Date) -> Int? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return nil }
        guard let children = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var count = 0
        for child in children {
            let v = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard v?.isDirectory == true else { continue }
            guard let mtime = v?.contentModificationDate, mtime >= since else { continue }
            count += 1
        }
        return count
    }
}
