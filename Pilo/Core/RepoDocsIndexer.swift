import Foundation

/// 项目文档面板：扫仓库根 + `docs/` / `doc/` / `notes/` / `design/` / `spec/` / `wiki/` / `.github/`，
/// 找"项目文档"类文件。AI coding 时代特别识别 CLAUDE.md / AGENTS.md / CURSOR.md 等。
///
/// 设计原则：
///   - 仓库根：所有 `.md` 都纳入（kind = .generic 兜底），prefix 命中的特殊分类
///   - 根级支持**无扩展白名单**：LICENSE / COPYING / AUTHORS 等
///   - docs/ 等子目录：递归 2 级（保性能，但抓到 docs/api/v1/spec.md 这种二级路径）
///   - mtime 倒序、limit 截断
///   - 不读文件内容（隐私 + 速度）
enum RepoDocsIndexer {

    /// 仓库根级 + 已知 prefix（lowercased）→ kind 映射。
    /// 第一个匹配的 prefix 决定 kind。**未命中**的 .md 仍然纳入，kind = .generic。
    private static let rootPrefixes: [(prefix: String, kind: RepoDoc.Kind)] = [
        // 经典开源
        ("readme",           .readme),
        ("changelog",        .changelog),
        ("changes",          .changelog),
        ("history",          .changelog),
        ("todo",             .todo),
        ("roadmap",          .todo),
        ("tasks",            .todo),
        ("prd",              .prd),
        ("requirements",     .prd),
        ("architecture",     .architecture),
        ("design",           .architecture),
        ("implementation",   .architecture),
        ("contributing",     .contributing),
        ("code_of_conduct",  .contributing),
        ("code-of-conduct",  .contributing),
        ("security",         .contributing),
        ("license",          .license),
        ("copying",          .license),
        ("authors",          .license),
        ("maintainers",      .license),
        ("notice",           .license),
        ("notes",            .notes),
        ("ideas",            .notes),
        // AI coding 时代专属
        ("claude",           .aiInstructions),
        ("agents",           .aiInstructions),
        ("cursor",           .aiInstructions),
        (".cursorrules",     .aiInstructions),
        ("ai",               .aiInstructions),
        ("pilo",             .aiInstructions),
        ("copilot",          .aiInstructions),
        ("windsurf",         .aiInstructions),
    ]

    /// 无扩展名"裸文件"白名单（GitHub 也按这个识别）。
    /// 命中后 kind 由 lowercased 名字 → rootPrefixes 推断。
    private static let bareFileWhitelist: Set<String> = [
        "license", "copying", "authors", "maintainers", "notice",
        "readme", "changelog", "todo", "contributors",
        ".cursorrules",  // Cursor IDE 配置，无扩展，AI coding 时代标配
    ]

    /// 文档扩展名（不在此列表的不视为文档；裸文件走 bareFileWhitelist）。
    /// `mdc` 是 Cursor 0.42+ 的 rules 文件新格式（如 .cursorrules.mdc / *.mdc）。
    private static let docExtensions: Set<String> = [
        "md", "markdown", "mdx", "mdc", "rst", "txt", "org",
    ]

    /// docs-like 子目录（一级深度全扫，二级有限递归）。
    private static let docDirNames: [String] = [
        "docs", "doc", "documentation", "notes", "design", "spec", "specs", "wiki", ".github",
    ]

    /// 子目录递归最大深度（从 docs/ 这一层开始算 1）。
    /// 3 覆盖 docs/api/v1/spec.md 这种 3 级嵌套（OpenAPI 等常见）；
    /// 再深就过头，避免性能 + 噪音。
    private static let subdirMaxDepth = 3

    /// 限制最大返回数。
    /// 重型项目（如 200+ 份文档）截到 100；UI 层用折叠/展开控制可见数。
    static let limit = 100

    /// 扫文档。同步阻塞，但只做几次 FileManager call，~毫秒级。
    /// 失败 / 空目录 → 返回 [].
    static func index(repoPath: String) -> [RepoDoc] {
        let fm = FileManager.default
        // 解析 symlink（macOS 上 /var → /private/var）
        let root = URL(fileURLWithPath: repoPath).resolvingSymlinksInPath()
        var docs: [RepoDoc] = []

        // 1) 仓库根
        if let rootContents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) {
            for url in rootContents {
                let name = url.lastPathComponent
                if name.hasPrefix(".") {
                    // 跳过 .env / .gitignore / .DS_Store 等隐藏文件；
                    // 放行：(a) 显式的 .cursorrules；(b) docs-like 隐藏目录（.github）；
                    //       (c) 任何"隐藏 + 文档扩展名"的文件（如 .cursorrules.mdc）
                    let ext = url.pathExtension.lowercased()
                    let isDocExt = !ext.isEmpty && docExtensions.contains(ext)
                    let isAllowedDotName = (name == ".cursorrules") || docDirNames.contains(name)
                    if !isDocExt && !isAllowedDotName {
                        continue
                    }
                }
                if let doc = makeDoc(url: url, repoRoot: root, atRootLevel: true) {
                    docs.append(doc)
                }
            }
        }

        // 2) docs-like 子目录（递归到 subdirMaxDepth）
        for sub in docDirNames {
            let subURL = root.appendingPathComponent(sub)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            scanSubdirectory(subURL, repoRoot: root, depth: 1, into: &docs)
        }

        // 排序：kind 权重在前（README / AI rules / LICENSE 等永远不被 generic 挤出），
        // 同权重内按 mtime 倒序。limit 截断保护重型项目。
        return Array(
            docs
                .sorted { lhs, rhs in
                    let lp = sortPriority(lhs.kind)
                    let rp = sortPriority(rhs.kind)
                    if lp != rp { return lp < rp }
                    return lhs.modifiedAt > rhs.modifiedAt
                }
                .prefix(limit)
        )
    }

    /// 排序优先级（数字越小越靠前）。重要 kind 永远进 top，避免被海量 .generic 挤掉。
    private static func sortPriority(_ kind: RepoDoc.Kind) -> Int {
        switch kind {
        case .readme:          return 0   // 最重要：项目门面
        case .aiInstructions:  return 1   // AI 时代专属：CLAUDE.md / .cursorrules
        case .architecture:    return 2   // 架构 / 实现记录
        case .prd:             return 3
        case .todo:            return 4
        case .changelog:       return 5
        case .contributing:    return 6
        case .license:         return 7
        case .notes:           return 8
        case .generic:         return 99  // 兜底
        }
    }

    // MARK: - 子目录递归

    private static func scanSubdirectory(
        _ dir: URL,
        repoRoot: URL,
        depth: Int,
        into docs: inout [RepoDoc]
    ) {
        guard depth <= subdirMaxDepth else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            if isDir {
                // 递归更深一层
                scanSubdirectory(url, repoRoot: repoRoot, depth: depth + 1, into: &docs)
            } else {
                if let doc = makeDoc(url: url, repoRoot: repoRoot, atRootLevel: false) {
                    docs.append(doc)
                }
            }
        }
    }

    // MARK: - 单文件 → RepoDoc

    private static func makeDoc(url: URL, repoRoot: URL, atRootLevel: Bool) -> RepoDoc? {
        let name = url.lastPathComponent
        let lowerName = name.lowercased()
        let ext = url.pathExtension.lowercased()

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { return nil }

        let kind: RepoDoc.Kind?

        if ext.isEmpty {
            // 无扩展名 → 仅识别已知裸文件名（仅根级）
            guard atRootLevel else { return nil }
            guard bareFileWhitelist.contains(lowerName) else { return nil }
            kind = classifyByPrefix(lowerName) ?? .license  // 兜底 license
        } else {
            // 有扩展名 → 必须是文档扩展名
            guard docExtensions.contains(ext) else { return nil }
            if atRootLevel {
                // 根级：prefix 命中分类；未命中也纳入（kind = .generic），允许 DESIGN_NOTES.md 等
                kind = classifyByPrefix(stem(of: lowerName)) ?? .generic
            } else {
                // 子目录：全部归 .generic
                kind = .generic
            }
        }

        guard let kind else { return nil }

        let size = values?.fileSize ?? 0
        let mtime = values?.contentModificationDate ?? Date()
        // 用 resolved URL 计算相对路径（避免 symlink 不一致）
        let resolved = url.resolvingSymlinksInPath()
        let relative = resolved.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
        return RepoDoc(
            kind: kind,
            relativePath: relative,
            name: name,
            sizeBytes: size,
            modifiedAt: mtime
        )
    }

    private static func classifyByPrefix(_ lowerStem: String) -> RepoDoc.Kind? {
        for entry in rootPrefixes {
            if lowerStem.hasPrefix(entry.prefix) {
                return entry.kind
            }
        }
        return nil
    }

    private static func stem(of lowerName: String) -> String {
        if let dot = lowerName.lastIndex(of: ".") {
            return String(lowerName[..<dot])
        }
        return lowerName
    }
}
