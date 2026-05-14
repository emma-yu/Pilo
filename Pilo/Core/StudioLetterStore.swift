import Foundation

/// 总局来信箱持久化：读写 `~/Library/Application Support/Pilo/studio-letters.json`。
/// 跟 ReleaseLetterStore / LetterStore 平行 —— 互不污染、各自向后兼容。
///
/// 坏数据自动备份后重置，启动绝不卡 IO 错误。
enum StudioLetterStore {
    static func load() -> StudioLetterArchive {
        let url = AppPaths.studioLettersJSON
        guard let data = try? Data(contentsOf: url) else { return .empty }
        do {
            return try JSONDecoder.pilo.decode(StudioLetterArchive.self, from: data)
        } catch {
            // 损坏 → 备份重置，启动不被一个坏字节卡住
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("studio-letters.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .empty
        }
    }

    static func save(_ archive: StudioLetterArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: AppPaths.studioLettersJSON, options: [.atomic])
        } catch {
            // 持久化失败不致命 —— 至少 in-memory 还能展示这次 session
        }
    }
}
