import Foundation

/// 项目文档面板：扫仓库根 + `docs/` / `doc/` 一级目录，找"项目文档"类文件。
///
/// 设计原则：
///   - 只看根 + 一级 docs/，**不递归**（性能）
///   - 不读文件内容（隐私 + 速度）
///   - 用文件名 prefix + 扩展名识别 kind
///   - 按 mtime 倒序排（用户最关心最近改过的）
///
/// 调用时机：用户 selectRepo 时按需触发（不放在全量扫盘里，避免拖慢启动）。
enum RepoDocsIndexer {

    /// 仓库根级文档的"前缀"识别表（大小写不敏感）。
    /// 第一个匹配的前缀决定 kind。
    private static let rootPrefixes: [(prefix: String, kind: RepoDoc.Kind)] = [
        ("readme",        .readme),
        ("changelog",     .changelog),
        ("changes",       .changelog),
        ("todo",          .todo),
        ("roadmap",       .todo),
        ("prd",           .prd),
        ("architecture",  .architecture),
        ("design",        .architecture),
        ("contributing",  .contributing),
        ("notes",         .notes),
        ("ideas",         .notes),
        ("implementation", .architecture),
    ]

    /// 文档扩展名（不在此列表的不视为文档）。
    private static let docExtensions: Set<String> = [
        "md", "markdown", "mdx", "rst", "txt", "org",
    ]

    /// 限制最大返回数（避免文档堆积时面板过长）。
    static let limit = 12

    /// 扫文档。同步阻塞，但只做几次 FileManager call，~毫秒级。
    /// 失败 / 空目录 → 返回 [].
    static func index(repoPath: String) -> [RepoDoc] {
        let fm = FileManager.default
        // 解析 symlink（macOS 上 /var → /private/var，否则相对路径计算会错）
        let root = URL(fileURLWithPath: repoPath).resolvingSymlinksInPath()
        var docs: [RepoDoc] = []

        // 1) 仓库根
        if let rootContents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for url in rootContents {
                if let doc = makeDoc(url: url, repoRoot: root, kindFor: classifyRootLevel) {
                    docs.append(doc)
                }
            }
        }

        // 2) docs/ 和 doc/ 一级
        for sub in ["docs", "doc", "documentation"] {
            let subURL = root.appendingPathComponent(sub)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if let subContents = try? fm.contentsOfDirectory(
                at: subURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for url in subContents {
                    if let doc = makeDoc(url: url, repoRoot: root, kindFor: { _ in .generic }) {
                        docs.append(doc)
                    }
                }
            }
        }

        // mtime 倒序排（最近改的在前），limit 截断
        return Array(docs.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(limit))
    }

    // MARK: - 内部

    private static func makeDoc(
        url: URL,
        repoRoot: URL,
        kindFor: (String) -> RepoDoc.Kind?
    ) -> RepoDoc? {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        guard docExtensions.contains(ext) else { return nil }
        guard let kind = kindFor(name.lowercased()) else { return nil }
        // 拿 size + mtime
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { return nil }
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

    /// 仓库根级：要求 prefix 命中识别表才算文档。
    /// （根级 md 太多了，比如随便一个 idea.md / scratch.md 也是 md，
    /// 但用户不一定想看 —— 限定 prefix 让结果可预期。）
    private static func classifyRootLevel(lowercaseName: String) -> RepoDoc.Kind? {
        // 去掉扩展名后再 prefix 匹配
        let stem: String = {
            if let dot = lowercaseName.lastIndex(of: ".") {
                return String(lowercaseName[..<dot])
            }
            return lowercaseName
        }()
        for entry in rootPrefixes {
            if stem.hasPrefix(entry.prefix) {
                return entry.kind
            }
        }
        return nil
    }
}
