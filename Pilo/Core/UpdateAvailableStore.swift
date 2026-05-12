import Foundation

/// 「新版本已发车」推送信持久化（update-available.json）。
/// 同时最多 1 封 —— 跟 LetterStore / ReleaseLetterStore 平行。
enum UpdateAvailableStore {
    static func load() -> UpdateAvailableArchive {
        let url = AppPaths.updateAvailableJSON
        guard let data = try? Data(contentsOf: url) else { return .empty }
        do {
            return try JSONDecoder.pilo.decode(UpdateAvailableArchive.self, from: data)
        } catch {
            // 坏数据 → 备份 + 重置
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("update-available.corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .empty
        }
    }

    static func save(_ archive: UpdateAvailableArchive) {
        do {
            let data = try JSONEncoder.pilo.encode(archive)
            try data.write(to: AppPaths.updateAvailableJSON, options: [.atomic])
        } catch {
            // 失败不致命
        }
    }
}
