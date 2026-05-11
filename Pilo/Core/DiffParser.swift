import Foundation

/// 把 `git diff --unified=0` 的输出解析成一串「这是新增的行 + 它在哪个文件第几行」。
///
/// 状态机：
///   - `diff --git a/X b/Y` → 重置当前文件，记下路径（取 b/ 这一侧）
///   - `Binary files ...`   → 标记当前文件为二进制，后续 `+` / `-` 都跳过
///   - `+++ b/X`            → 备用路径解析路径（应和 `diff --git` 一致）
///   - `@@ -a,b +c,d @@`    → 重置新行号 = c
///   - `+content`           → 当前文件 + 当前行号 → 输出 DiffLine；行号 ++
///   - ` content`           → 行号 ++（context，不输出）
///   - `-content`           → 行号不变（删除，不影响新版本编号）
enum DiffParser {

    static func parse(_ rawDiff: String) -> [DiffLine] {
        var out: [DiffLine] = []
        var currentFile: String?
        var isBinary = false
        var newLineNumber: Int = 0

        // 用 components(separatedBy:) 而不是 split，保留空行
        for line in rawDiff.split(separator: "\n", omittingEmptySubsequences: false) {
            let l = String(line)

            if l.hasPrefix("diff --git ") {
                // 形如 "diff --git a/path b/path"
                currentFile = extractBPath(from: l)
                isBinary = false
                newLineNumber = 0
                continue
            }

            if l.hasPrefix("Binary files ") {
                isBinary = true
                continue
            }

            if l.hasPrefix("+++ b/") {
                // 路径在 diff --git 行没解析出来时的兜底
                if currentFile == nil {
                    currentFile = String(l.dropFirst("+++ b/".count))
                }
                continue
            }

            if l.hasPrefix("@@") {
                // "@@ -1,3 +12,5 @@..." → 提取 c
                if let parsed = parseHunkHeader(l) {
                    newLineNumber = parsed
                }
                continue
            }

            guard !isBinary, let file = currentFile else { continue }

            if l.hasPrefix("+") && !l.hasPrefix("+++") {
                let content = String(l.dropFirst())
                out.append(DiffLine(filePath: file, newLineNumber: newLineNumber, content: content))
                newLineNumber += 1
            } else if l.hasPrefix("-") && !l.hasPrefix("---") {
                // deletion — new line counter 不动
                continue
            } else if l.hasPrefix(" ") || l.isEmpty {
                // context line
                newLineNumber += 1
            }
            // 其他元数据行（"index ...", "Binary..." 之外的奇怪行）跳过
        }

        return out
    }

    // MARK: - 私有解析

    /// 从 "diff --git a/foo/bar b/foo/baz" 取 "foo/baz"
    private static func extractBPath(from line: String) -> String? {
        // 找最后一个 " b/"，从那之后到末尾
        guard let range = line.range(of: " b/", options: .backwards) else { return nil }
        return String(line[range.upperBound...])
    }

    /// 从 "@@ -1,3 +12,5 @@ ..." 取 12
    private static func parseHunkHeader(_ line: String) -> Int? {
        // 找 "+" 后的数字
        guard let plusRange = line.range(of: "+") else { return nil }
        let afterPlus = line[plusRange.upperBound...]
        // 取到下一个 ',' 或 ' '
        var numberStr = ""
        for ch in afterPlus {
            if ch.isNumber { numberStr.append(ch) }
            else { break }
        }
        return Int(numberStr)
    }
}
