import Foundation

/// `git diff` 解析后给 SecretScanner 用的最小信息单元：
/// 一行**新增**的内容，加上它在新版本里的位置。
///
/// 我们只扫描 `+` 行（添加），不扫 ` ` (context) 也不扫 `-` (删除)。
/// 删除一段敏感信息不是泄漏，是修复——不应该再次提醒用户。
struct DiffLine: Sendable, Hashable {
    let filePath: String        // 相对仓库根
    let newLineNumber: Int      // 在新版本里的行号（1-based）
    let content: String         // 这一行的内容（不含 `+` 前缀）
}
