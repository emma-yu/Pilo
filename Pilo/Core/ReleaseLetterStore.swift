import Foundation

/// 版本通告信箱持久化：读写 `~/Library/Application Support/Pilo/release-letters.json`。
/// 跟 LetterStore（每日工作总结）平行 —— 互不污染、各自向后兼容。
///
/// 坏数据自动备份后重置，启动绝不卡 IO 错误。
enum ReleaseLetterStore {
    static func load() -> ReleaseLetterArchive {
        let url = AppPaths.releaseLettersJSON
        guard let data = try? Data(contentsOf: url) else { return .empty }
        do {
            return try JSONDecoder.pilo.decode(ReleaseLetterArchive.self, from: data)
        } catch {
            // 损坏 → 备份重置，启动不被一个坏字节卡住
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("release-letters.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .empty
        }
    }

    static func save(_ archive: ReleaseLetterArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: AppPaths.releaseLettersJSON, options: [.atomic])
        } catch {
            // 持久化失败不致命 —— 至少 in-memory 还能展示这次 session
        }
    }
}
