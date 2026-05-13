import Foundation

/// 邮票本持久化：读写 `~/Library/Application Support/Pilo/prompt-stamps.json`。
/// 跟 LetterStore / ReleaseLetterStore 平行 —— 各自向后兼容，互不污染。
///
/// 坏数据自动备份后重置，启动绝不卡 IO 错误。
///
/// **测试隔离**：`testOverrideURL` 让 unit test 把读写重定向到 temp 目录，
/// 避免测试通过 `AppState.addPromptStamp` 等 CRUD 走真生产文件 ——
/// 历史上吃过亏：测试运行 = user 真实邮票被清空。
enum PromptStampStore {
    /// 测试 hook。设非 nil → load/save 都走这个 URL；nil = 生产路径
    nonisolated(unsafe) static var testOverrideURL: URL?

    private static var url: URL { testOverrideURL ?? AppPaths.promptStampsJSON }

    static func load() -> PromptStampArchive {
        let fileURL = url
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        do {
            return try JSONDecoder.pilo.decode(PromptStampArchive.self, from: data)
        } catch {
            // 坏 JSON → 备份重置，启动不被一个坏字节卡住
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("prompt-stamps.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return .empty
        }
    }

    static func save(_ archive: PromptStampArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: url, options: [.atomic])
        } catch {
            // 持久化失败不致命 —— at least in-memory 还能展示这次 session
        }
    }
}
