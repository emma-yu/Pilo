import Foundation

/// 读取跟 app binary 一起 bundle 的 `release-notes.json`，解析成 BundledRelease 数组。
///
/// **何时被读**：AppState 启动时一次。失败完全静默（返回 []），不影响 app 启动。
///
/// 文件格式（`Pilo/Resources/release-notes.json`）：
/// ```json
/// {
///   "schemaVersion": 1,
///   "releases": [
///     {
///       "version": "0.4.0",
///       "releaseDate": "2026-05-12",
///       "title": "...",
///       "highlights": ["..."],
///       "body": ["..."]
///     }
///   ]
/// }
/// ```
enum ReleaseNotesLoader {

    static func bundledReleases() -> [BundledRelease] {
        guard let url = Bundle.main.url(forResource: "release-notes", withExtension: "json") else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            // "2026-05-12" → Date（用户本地的午夜）
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = .current
            if let d = fmt.date(from: raw) { return d }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected yyyy-MM-dd, got \(raw)"
            )
        }
        do {
            let bundle = try decoder.decode(BundledReleaseFile.self, from: data)
            return bundle.releases
        } catch {
            // 解析失败 → 静默空数组（避免发坏 release-notes.json 时 app 启动崩）
            return []
        }
    }

    /// 当前 app 的语义版本（从 Info.plist 读）。nil = Info.plist 缺这字段
    static func currentAppVersion() -> String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

/// `release-notes.json` 顶层结构
struct BundledReleaseFile: Codable, Sendable {
    let schemaVersion: Int
    let releases: [BundledRelease]
}

/// 单个版本条目（authoring 时写，不持久化用户状态）
struct BundledRelease: Codable, Sendable, Hashable {
    let version: String          // "0.4.0"
    let releaseDate: Date        // 解码自 "2026-05-12"
    let title: String
    let highlights: [String]
    let body: [String]
}
