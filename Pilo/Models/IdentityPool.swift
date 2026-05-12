import Foundation

/// S3 Identity Sentinel：用户给每类 RepoCategory 配的预期 git user.email。
/// 持久化在 UserDefaults（不在 state.json，因为这是用户偏好不是仓库元数据）。
struct IdentityPool: Sendable, Hashable {
    let work: String?
    let personal: String?
    let experiment: String?

    /// 给一个 category 返回期望的 email。
    /// 特例：experiment 留空时回退到 personal —— 实验项目通常跟个人共用 identity
    func expectedEmail(for category: RepoCategory) -> String? {
        switch category {
        case .work:       return nonEmpty(work)
        case .personal:   return nonEmpty(personal)
        case .experiment: return nonEmpty(experiment) ?? nonEmpty(personal)
        case .unset:      return nil    // 未分类不检查
        }
    }

    /// 整个 pool 是否完全未配置 —— 用来决定要不要跑 identity check
    var isEmpty: Bool {
        nonEmpty(work) == nil && nonEmpty(personal) == nil && nonEmpty(experiment) == nil
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }

    // MARK: - UserDefaults 读写

    static func load() -> IdentityPool {
        let ud = UserDefaults.standard
        return IdentityPool(
            work:       ud.string(forKey: SettingsKey.identityWork.rawValue),
            personal:   ud.string(forKey: SettingsKey.identityPersonal.rawValue),
            experiment: ud.string(forKey: SettingsKey.identityExperiment.rawValue)
        )
    }

    static func save(_ pool: IdentityPool) {
        let ud = UserDefaults.standard
        // 空字符串清掉 key 而非存空串，让 isEmpty 检查准确
        for (raw, key) in [
            (pool.work,       SettingsKey.identityWork.rawValue),
            (pool.personal,   SettingsKey.identityPersonal.rawValue),
            (pool.experiment, SettingsKey.identityExperiment.rawValue),
        ] {
            let trimmed = raw?.trimmingCharacters(in: .whitespaces) ?? ""
            if trimmed.isEmpty {
                ud.removeObject(forKey: key)
            } else {
                ud.set(trimmed, forKey: key)
            }
        }
    }
}
