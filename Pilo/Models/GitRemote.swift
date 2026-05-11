import Foundation

struct GitRemote: Codable, Hashable, Sendable {
    var name: String        // "origin" / "upstream" / ...
    var url: String
    var isPublic: Bool?     // v0.1: 永远为 nil；后续 Phase 用 GitHub API 填充

    var displayHost: String {
        // 提取 host 用于显示，例如 "github.com/emma/uvpeek"
        // 兼容 git@github.com:emma/uvpeek.git 和 https://github.com/emma/uvpeek.git
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
