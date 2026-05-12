import Foundation

/// S3 Identity Sentinel：检查 repo 当前 git identity（local user.email + 待推
/// commits 的 author email）是否跟 RepoCategory 期望的 IdentityPool 匹配。
///
/// 核心场景：用户在 work repo 不小心用了 personal email commit，Pilo push 前提醒。
/// 边缘 case：GitHub noreply `<id>+<username>@users.noreply.github.com` 视为
/// 同一身份的别名（这是 GitHub 推荐做法，跟普通 email 应该等价比较 username 部分）。
enum IdentityValidator {

    /// Push preflight 检测到的 identity 错位。
    struct Mismatch: Sendable, Hashable {
        /// IdentityPool 期望的 email
        let expectedEmail: String
        /// 实际不匹配的 email（多个不一致取出现最多的，简化先取第一个）
        let actualEmail: String
        /// 不匹配的 commit 数（用作 banner 说明）
        let mismatchCount: Int
        /// 该 repo 的 category
        let category: RepoCategory
        /// 当前 git config user.email（可能跟 actualEmail 不同：用户当前 config
        /// 改对了但 commits 是旧 email）
        let currentLocalEmail: String?
    }

    /// 主入口：检查这次 push 的 commits 是不是都用了期望的 identity。
    /// - Parameters:
    ///   - category: repo 的 RepoCategory
    ///   - identityPool: 用户配的 identity pool
    ///   - commits: 待推 commits
    ///   - currentLocalEmail: `git config user.email` 在本 repo 的值
    /// - Returns: nil 表示无 mismatch；non-nil 表示发现错位
    static func validate(
        category: RepoCategory,
        identityPool: IdentityPool,
        commits: [CommitSummary],
        currentLocalEmail: String?
    ) -> Mismatch? {
        // unset 类别或 pool 完全空 → 跳过检查
        guard let expected = identityPool.expectedEmail(for: category) else { return nil }
        guard !commits.isEmpty else { return nil }

        // 数 mismatch
        var mismatchEmails: [String: Int] = [:]
        for c in commits {
            let actual = c.authorEmail ?? ""   // CommitSummary 当前没 email，下面会补
            if !isSameIdentity(actual, expected) {
                mismatchEmails[actual, default: 0] += 1
            }
        }

        guard let topMismatch = mismatchEmails.max(by: { $0.value < $1.value }) else {
            return nil    // 所有 commits 都匹配
        }

        return Mismatch(
            expectedEmail: expected,
            actualEmail: topMismatch.key,
            mismatchCount: mismatchEmails.values.reduce(0, +),
            category: category,
            currentLocalEmail: currentLocalEmail
        )
    }

    /// 判断两个 email 是不是"同一身份"。
    /// 规则：
    ///   1. 完全相同（case-insensitive）→ 同
    ///   2. 都是 GitHub noreply `<id>+<username>@users.noreply.github.com` 时，
    ///      比较 `+` 后的 username 部分 → 同
    ///   3. 一边是 noreply、另一边是普通 email 时，如果 noreply 的 username
    ///      跟普通 email 的 local-part 完全相同 → 视为同（很多人在 settings 里
    ///      隐藏真实 email 后只有 noreply，配置时可能写真实 email）
    ///   4. 其他 → 不同
    static func isSameIdentity(_ a: String, _ b: String) -> Bool {
        let lhs = a.lowercased().trimmingCharacters(in: .whitespaces)
        let rhs = b.lowercased().trimmingCharacters(in: .whitespaces)
        if lhs == rhs { return true }
        if lhs.isEmpty || rhs.isEmpty { return false }

        let lUser = noreplyUsername(lhs)
        let rUser = noreplyUsername(rhs)
        // 都 noreply 且 username 相同
        if let l = lUser, let r = rUser { return l == r }

        // 一边 noreply，另一边 plain：比较 noreply 的 username 跟 plain 的 local-part
        if let l = lUser {
            let rLocal = rhs.split(separator: "@").first.map(String.init) ?? rhs
            return l == rLocal
        }
        if let r = rUser {
            let lLocal = lhs.split(separator: "@").first.map(String.init) ?? lhs
            return lLocal == r
        }

        return false
    }

    /// 解析 GitHub noreply email 的 username 部分。
    /// 格式：`<id>+<username>@users.noreply.github.com` 或老格式 `<username>@users.noreply.github.com`
    private static func noreplyUsername(_ email: String) -> String? {
        guard email.hasSuffix("@users.noreply.github.com") else { return nil }
        let local = email.replacingOccurrences(of: "@users.noreply.github.com", with: "")
        // 新格式带 id+
        if let plus = local.firstIndex(of: "+") {
            return String(local[local.index(after: plus)...])
        }
        return local
    }
}
