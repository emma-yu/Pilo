import Foundation
import CryptoKit

/// Per-doc 滚动位置记忆。长文档（如 IMPLEMENTATION.md / roadmap）的"上次读到哪"恢复。
///
/// 存储策略：**blockIndex 而非 pixel offset**：
///   - pixel offset 随字号 / 窗口大小变化，重启就错位
///   - blockIndex 跟 markdown 结构绑定，文档轻编辑后仍近似有效
///   - 最坏情况：内容改动后跳到附近 ±N 块，不会错位 200 行
///
/// Key 设计：SHA256(repoPath + relativePath) 前 16 hex —— 全局唯一，路径变动失效（也安全）
///
/// UserDefaults 容量：每 doc 一个 Int + 一个 key 名，~80 bytes 每条；
/// 1000 文档 = ~80KB，远低于 UserDefaults 警戒线
enum DocReadingMemory {

    private static let keyPrefix = "docScroll."

    /// 取回上次保存的块索引；nil = 没存过 / 已 clear
    static func savedBlockIndex(repoPath: String, docRelativePath: String) -> Int? {
        let key = storageKey(repoPath: repoPath, docRelativePath: docRelativePath)
        // UserDefaults.integer(forKey:) 在 key 不存在时返回 0，无法区分"没存"和"存了 0"
        // —— 用 object(forKey:) 显式 nil 检查
        guard let value = UserDefaults.standard.object(forKey: key) as? Int else { return nil }
        return value
    }

    static func save(blockIndex: Int, repoPath: String, docRelativePath: String) {
        let key = storageKey(repoPath: repoPath, docRelativePath: docRelativePath)
        UserDefaults.standard.set(blockIndex, forKey: key)
    }

    static func clear(repoPath: String, docRelativePath: String) {
        let key = storageKey(repoPath: repoPath, docRelativePath: docRelativePath)
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 内部

    /// 用 SHA256(repoPath + "::" + docRelativePath) 前 16 hex 当 key
    /// 分隔符 "::" 避免边界混淆（如果 repoPath 末尾恰好等于 docRelativePath 开头）
    static func storageKey(repoPath: String, docRelativePath: String) -> String {
        let combined = repoPath + "::" + docRelativePath
        let digest = SHA256.hash(data: Data(combined.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return keyPrefix + String(hex.prefix(16))
    }
}
