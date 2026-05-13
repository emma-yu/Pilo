import Foundation

/// 邮票本持久化：读写 `~/Library/Application Support/Pilo/prompt-stamps.json`。
/// 跟 LetterStore / ReleaseLetterStore 平行 —— 各自向后兼容，互不污染。
///
/// 坏数据自动备份后重置，启动绝不卡 IO 错误。
enum PromptStampStore {
    static func load() -> PromptStampArchive {
        let url = AppPaths.promptStampsJSON
        guard let data = try? Data(contentsOf: url) else { return .empty }
        do {
            return try JSONDecoder.pilo.decode(PromptStampArchive.self, from: data)
        } catch {
            // 坏 JSON → 备份重置，启动不被一个坏字节卡住
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("prompt-stamps.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .empty
        }
    }

    static func save(_ archive: PromptStampArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: AppPaths.promptStampsJSON, options: [.atomic])
        } catch {
            // 持久化失败不致命 —— at least in-memory 还能展示这次 session
        }
    }
}
