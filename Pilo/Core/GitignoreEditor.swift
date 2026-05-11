import Foundation

/// 安全地往仓库根 `.gitignore` 追加模式。
///
/// 设计：幂等 + 不动已有内容 + 保留用户的注释和分组。
/// 永远只**追加**到末尾，永远不删除已有行。
enum GitignoreEditor {

    struct Result: Sendable {
        let addedLines: [String]
        let alreadyPresent: [String]
        let gitignorePath: String
    }

    /// 把给定的模式集合追加到 repo 根 .gitignore。
    /// `pattern` 可以是多行（如 ".env\n.env.*\n!.env.example"），逐行处理。
    /// 已经存在的行跳过；本次新加的行集中放在末尾一个块里，带 Pilo 时间戳注释。
    @discardableResult
    static func append(pattern: String, toRepoAt repoPath: String) throws -> Result {
        let gitignoreURL = URL(fileURLWithPath: repoPath).appendingPathComponent(".gitignore")
        let existingContent = (try? String(contentsOf: gitignoreURL, encoding: .utf8)) ?? ""
        let existingLines = Set(existingContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))

        let candidateLines = pattern.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var toAdd: [String] = []
        var alreadyPresent: [String] = []
        for line in candidateLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if existingLines.contains(line) || existingLines.contains(trimmed) {
                alreadyPresent.append(line)
            } else {
                toAdd.append(line)
            }
        }

        var newContent = existingContent
        if !toAdd.isEmpty {
            // 保证文件以换行结尾
            if !newContent.isEmpty && !newContent.hasSuffix("\n") {
                newContent += "\n"
            }
            // 块状追加，带时间戳注释，方便用户日后找到 Pilo 的痕迹
            let stamp = ISO8601DateFormatter().string(from: Date())
            newContent += "\n# Added by Pilo at \(stamp)\n"
            newContent += toAdd.joined(separator: "\n") + "\n"
        }

        if newContent != existingContent {
            try newContent.write(to: gitignoreURL, atomically: true, encoding: .utf8)
        }

        return Result(
            addedLines: toAdd,
            alreadyPresent: alreadyPresent,
            gitignorePath: gitignoreURL.path
        )
    }
}
