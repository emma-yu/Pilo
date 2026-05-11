import Foundation

/// 递归扫描 watch directories，找到所有 git 仓库，调用 GitClient 填元数据。
/// 单 actor 隔离避免共享状态；最多 4 个仓库并发查询元数据。
actor RepoScanner {

    static let ignoredDirNames: Set<String> = [
        "node_modules", "vendor", ".build", "Pods", "DerivedData",
        ".next", ".nuxt", "dist", "build", "out", "target",
        ".venv", "venv", "__pycache__", ".tox",
        ".gradle", ".idea", ".vscode",
    ]

    static let maxDepth = 6
    static let concurrency = 4

    let gitClient: GitClient

    init(gitClient: GitClient) {
        self.gitClient = gitClient
    }

    /// 主入口：扫描一组 watch 目录，返回仓库列表。
    func scan(watchDirs: [URL]) async -> [Repository] {
        // Step 1: 发现 .git 目录
        var foundRepos: [URL] = []
        for dir in watchDirs {
            foundRepos.append(contentsOf: discoverRepos(at: dir, depth: 0))
        }

        // 去重（用户可能指定了嵌套的 watch dirs）
        let uniquePaths = Array(Set(foundRepos.map(\.path)))
            .map { URL(fileURLWithPath: $0) }
            .sorted { $0.path < $1.path }

        // Step 2: 并发填充元数据
        return await fillMetadata(for: uniquePaths)
    }

    // MARK: - 发现阶段

    private func discoverRepos(at url: URL, depth: Int) -> [URL] {
        guard depth <= Self.maxDepth else { return [] }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else {
            return []
        }

        // 当前目录就是仓库根？
        let gitDir = url.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitDir.path) {
            // 是 git 仓库；不再递归（仓库内部的 submodule 等本期不处理）
            return [url]
        }

        // 否则递归子目录
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        )) ?? []

        var found: [URL] = []
        for item in contents {
            let name = item.lastPathComponent
            if Self.ignoredDirNames.contains(name) { continue }
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true else { continue }
            if values?.isSymbolicLink == true { continue }   // 不跟符号链接，防环
            found.append(contentsOf: discoverRepos(at: item, depth: depth + 1))
        }
        return found
    }

    // MARK: - 元数据填充

    private func fillMetadata(for paths: [URL]) async -> [Repository] {
        guard !paths.isEmpty else { return [] }

        var results: [Repository] = []
        results.reserveCapacity(paths.count)

        // 按 concurrency 分批，避免一次创建上千 Task
        let chunks = paths.chunked(into: Self.concurrency)
        for chunk in chunks {
            let chunkResult = await withTaskGroup(of: Repository?.self) { group in
                for url in chunk {
                    group.addTask { [gitClient] in
                        await Self.buildRepository(at: url, gitClient: gitClient)
                    }
                }
                var collected: [Repository] = []
                for await item in group {
                    if let item { collected.append(item) }
                }
                return collected
            }
            results.append(contentsOf: chunkResult)
        }
        return results
    }

    private static func buildRepository(at url: URL, gitClient: GitClient) async -> Repository? {
        async let branch = gitClient.currentBranch(repo: url)
        async let uncommitted = gitClient.uncommittedCount(repo: url)
        async let remotes = gitClient.remotes(repo: url)
        async let lastCommit = gitClient.lastCommitDate(repo: url)
        async let firstCommit = gitClient.firstCommitHash(repo: url)

        let b = await branch
        let unc = await uncommitted
        let rem = await remotes
        let last = await lastCommit
        let first = await firstCommit

        var ahead = 0
        var behind = 0
        if let branchName = b {
            let ab = await gitClient.aheadBehind(repo: url, branch: branchName, remote: "origin")
            ahead = ab.ahead
            behind = ab.behind
        }

        // Phase B (Project Inventory)：扫盘时一并 detect 健康信号
        let health = RepoHealthDetector.detect(repoPath: url.path)

        return Repository(
            path: url.path,
            currentBranch: b,
            aheadCount: ahead,
            behindCount: behind,
            uncommittedCount: unc,
            lastCommitDate: last,
            remotes: rem,
            firstCommitHash: first,
            hasReadme: health.hasReadme,
            hasTests: health.hasTests
        )
    }
}

// MARK: - 工具

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        var idx = 0
        while idx < count {
            let end = Swift.min(idx + size, count)
            chunks.append(Array(self[idx..<end]))
            idx = end
        }
        return chunks
    }
}
