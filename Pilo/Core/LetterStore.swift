import Foundation

/// 信件持久化：读写 `~/Library/Application Support/Pilo/letters.json`
/// 单一访问点。坏数据备份后重置 archive。
enum LetterStore {

    /// 从盘读 archive；不存在 / 损坏 → empty archive
    static func load() -> LetterArchive {
        let url = AppPaths.lettersJSON
        guard let data = try? Data(contentsOf: url) else {
            return .empty
        }
        do {
            return try JSONDecoder.pilo.decode(LetterArchive.self, from: data)
        } catch {
            // 损坏 → 备份后返回 empty，不阻塞 app
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("letters.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .empty
        }
    }

    /// 持久化整本 archive。atomic write，失败不致命。
    static func save(_ archive: LetterArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: AppPaths.lettersJSON, options: [.atomic])
        } catch {
            // 持久化失败不致命；信件下次启动重新生成
        }
    }
}
