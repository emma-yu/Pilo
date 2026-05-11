import Foundation

struct GitRemote: Codable, Hashable, Sendable {
    var name: String        // "origin" / "upstream" / ...
    var url: String         // **已脱敏**——所有构造路径都强制走 sanitize
    var isPublic: Bool?     // v0.1: 永远为 nil；后续 Phase 用 GitHub API 填充

    init(name: String, url: String, isPublic: Bool? = nil) {
        self.name = name
        self.url = Self.sanitize(rawURL: url)
        self.isPublic = isPublic
    }

    // Codable：解码时也必须脱敏，否则旧 state.json 里残留的凭证会被读回来
    private enum CodingKeys: String, CodingKey { case name, url, isPublic }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.url = Self.sanitize(rawURL: try c.decode(String.self, forKey: .url))
        self.isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic)
    }

    /// 剥掉 URL 中嵌入的凭证（user / password / PAT）。
    /// 例：`https://user:ghp_xxx@github.com/a/b.git` → `https://github.com/a/b.git`
    /// SSH 形式 `git@host:foo` 不带凭证，原样返回。
    /// 这是 Pilo 的硬安全规则：UI 和 state.json 都**绝不**保留凭证。
    static func sanitize(rawURL: String) -> String {
        // SSH form `git@host:user/repo` — URLComponents 无法解析，直接放过
        if rawURL.hasPrefix("git@") || rawURL.hasPrefix("ssh://") {
            return rawURL
        }
        guard var components = URLComponents(string: rawURL) else { return rawURL }
        // 同时清掉 user 和 password 字段
        if components.user != nil || components.password != nil {
            components.user = nil
            components.password = nil
        }
        return components.string ?? rawURL
    }

    var displayHost: String {
        // 提取 host 用于显示，例如 "github.com/emma/uvpeek"
        if url.hasPrefix("git@") {
            let s = url.replacingOccurrences(of: "git@", with: "")
                       .replacingOccurrences(of: ":", with: "/")
                       .replacingOccurrences(of: ".git", with: "")
            return s
        }
        if let u = URL(string: url) {
            let host = u.host ?? ""
            let path = u.path.replacingOccurrences(of: ".git", with: "")
            return host + path
        }
        return url
    }
}
