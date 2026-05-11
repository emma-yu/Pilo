import Foundation

/// Phase B (Project Inventory)：仓库根部"健康信号"轻量检测。
///
/// **只看仓库根**（跟 GitHub 显示 README/tests 的逻辑一致）。
/// **不进 git history**、**不读文件内容**、**不递归**——纯 FileManager 几次 lookup，几毫秒。
/// 在 RepoScanner.buildRepository 里每次扫描调用一次。
enum RepoHealthDetector {

    /// 仓库根可识别为 README 的文件名（GitHub 也按这个集合识别）。
    static let readmeCandidates: [String] = [
        "README.md", "README.MD", "Readme.md", "readme.md",
        "README", "Readme", "readme",
        "README.txt", "README.rst", "README.org",
    ]

    /// 测试目录约定（覆盖主流语言 / 框架）。
    static let testDirCandidates: [String] = [
        "tests", "test", "Tests",
        "__tests__",       // jest
        "spec", "specs",   // ruby / rspec
        "e2e",
    ]

    /// 测试目录后缀（Swift / Kotlin 等 `XxxTests/`）。
    static let testDirSuffixes: [String] = ["Tests", "Test"]

    /// 单文件级别的测试约定（不在目录里的）。
    static let testFileSuffixes: [String] = [
        ".test.ts", ".test.tsx", ".test.js", ".test.jsx",
        ".spec.ts", ".spec.tsx", ".spec.js", ".spec.jsx",
        "_test.go", "_test.py",
    ]

    struct Result: Sendable {
        let hasReadme: Bool
        let hasTests: Bool
    }

    /// 检测仓库根。
    static func detect(repoPath: String) -> Result {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: repoPath)

        // 1) README ——仅检查根级文件存在
        let hasReadme = readmeCandidates.contains { candidate in
            fm.fileExists(atPath: root.appendingPathComponent(candidate).path)
        }

        // 2) Tests —— 检查根级目录 + 根级文件后缀
        let topLevel = (try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )) ?? []

        var hasTests = false
        for url in topLevel {
            let name = url.lastPathComponent
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            if isDir {
                if testDirCandidates.contains(name) {
                    hasTests = true
                    break
                }
                if testDirSuffixes.contains(where: { name.hasSuffix($0) && name.count > $0.count }) {
                    hasTests = true
                    break
                }
            } else {
                if testFileSuffixes.contains(where: { name.hasSuffix($0) }) {
                    hasTests = true
                    break
                }
            }
        }

        return Result(hasReadme: hasReadme, hasTests: hasTests)
    }
}
