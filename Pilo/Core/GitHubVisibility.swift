import Foundation

/// 用 GitHub **公共** REST API 检测仓库可见性。**无需 token**——
/// `GET api.github.com/repos/{owner}/{repo}`
///   - 200 + `"private": false` → 公开
///   - 200 + `"private": true`  → 私有（已认证场景，token 必须存在）
///   - 404                       → 私有或不存在（保守视作私有）
///   - 403 / 429                 → 限流，标 unknown 待下次
///   - 其他                       → unknown
///
/// 限流：未认证 60/hour。AppState 配合 24h 本地缓存避免反复打。
enum GitHubVisibility: String, Codable, Sendable {
    case publicRepo
    case privateRepo
    case unknown
}

actor GitHubVisibilityClient {

    struct OwnerRepo: Hashable, Sendable {
        let owner: String
        let repo: String
    }

    /// 从 GitRemote URL 解析 owner/repo。仅识别 github.com。
    /// 兼容：
    ///   https://github.com/emma/foo(.git)?
    ///   git@github.com:emma/foo(.git)?
    ///   ssh://git@github.com/emma/foo(.git)?
    static func parseOwnerRepo(from url: String) -> OwnerRepo? {
        // 干掉前缀
        var working = url
        for prefix in ["https://", "http://", "ssh://", "git@", "git://"] {
            if working.hasPrefix(prefix) {
                working = String(working.dropFirst(prefix.count))
                break
            }
        }
        // 找 github.com
        let host = "github.com"
        guard let hostRange = working.range(of: host) else { return nil }
        var path = String(working[hostRange.upperBound...])
        // 干掉分隔符（: 或 /）
        if path.hasPrefix(":") || path.hasPrefix("/") {
            path.removeFirst()
        }
        // 干掉尾部 .git
        if path.hasSuffix(".git") {
            path = String(path.dropLast(4))
        }
        // 切 owner/repo
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }
        return OwnerRepo(owner: String(parts[0]), repo: String(parts[1]))
    }

    /// 查一次 GitHub API。永远不抛错——网络问题、限流都返回 `.unknown`。
    func fetch(_ or: OwnerRepo) async -> GitHubVisibility {
        guard let url = URL(string: "https://api.github.com/repos/\(or.owner)/\(or.repo)") else {
            return .unknown
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Pilo/0.1", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .unknown }

            switch http.statusCode {
            case 200:
                struct R: Decodable { let `private`: Bool }
                if let r = try? JSONDecoder().decode(R.self, from: data) {
                    return r.private ? .privateRepo : .publicRepo
                }
                return .unknown
            case 404:
                return .privateRepo   // 不存在或无权访问——保守视作私有
            default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }
}
