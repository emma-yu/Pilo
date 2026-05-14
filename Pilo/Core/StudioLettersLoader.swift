import Foundation

/// 读取跟 app binary 一起 bundle 的 `studio-letters.json`，解析成 BundledStudioLetter 数组。
///
/// **何时被读**：AppState 启动时一次（在 injectNewStudioLettersIfNeeded 内）。
/// **失败策略**：完全静默（返回 []），不影响 app 启动。
///
/// 文件格式（`Pilo/Resources/studio-letters.json`）:
/// ```json
/// {
///   "schemaVersion": 1,
///   "letters": [
///     {
///       "id": "2026-postal-annual",
///       "sentDate": "2026-05-14",
///       "title": "...",
///       "highlights": ["..."],
///       "body": ["..."],
///       "cta": { "label": "...", "url": "https://..." }
///     }
///   ]
/// }
/// ```
enum StudioLettersLoader {

    static func bundledLetters() -> [BundledStudioLetter] {
        guard let url = Bundle.main.url(forResource: "studio-letters", withExtension: "json") else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            // "2026-05-14" → Date（用户本地时区的午夜）
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
            let bundle = try decoder.decode(BundledStudioLetterFile.self, from: data)
            return bundle.letters
        } catch {
            // 解析失败 → 静默空数组（避免发坏 JSON 时 app 启动崩）
            return []
        }
    }
}

/// `studio-letters.json` 顶层结构
struct BundledStudioLetterFile: Codable, Sendable {
    let schemaVersion: Int
    let letters: [BundledStudioLetter]
}

/// 单个总局来信条目（authoring time 写）
struct BundledStudioLetter: Codable, Sendable, Hashable {
    /// 稳定字符串 id（用作去重）
    let id: String
    let sentDate: Date
    let title: String
    let highlights: [String]
    let body: [String]
    let cta: BundledStudioLetterCTA?
}

struct BundledStudioLetterCTA: Codable, Sendable, Hashable {
    let label: String
    let url: URL
}
