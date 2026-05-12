import Foundation

/// 检查 Pilo 自身是否有新版本可下载。
///
/// **数据流**：
///   1. 每天 GET 一次远端 `updates.json` manifest（你 GitHub repo 的 raw 文件）
///   2. 对比 manifest.latest.version vs 当前 bundle version
///   3. 新 → 生成 UpdateAvailableLetter 写入信箱；用户在主面板 inbox pill 看到未读
///   4. 用户点信 → ReaderView 「下载新版本」按钮 → 打开 downloadURL
///
/// **隐私边界**：
///   - 仅 GET 一个静态 JSON 文件
///   - **不发送任何用户数据 / 仓库信息 / 用户名 / 机器 ID**
///   - server 只能从 IP 推断"有人访问了 manifest"——零关联用户身份
///
/// **失败哲学**：所有网络 / 解析失败完全静默；老 UpdateAvailableLetter 保留不动
actor UpdateChecker {

    /// 默认 manifest URL —— Emma 在自己 GitHub repo 维护 updates.json
    /// 修这里就改了全 app 的更新源（无需改 Settings UI）
    static let defaultManifestURL = URL(string: "https://raw.githubusercontent.com/emma-yu/Pilo/main/updates.json")!

    /// 检查频率：24h 一次（避免无谓的网络）
    static let checkInterval: TimeInterval = 24 * 3600

    /// 网络 fetch 抽象 —— 测试时注入 mock，生产用默认 URLSession
    typealias Fetcher = @Sendable (URL) async -> Data?

    private let manifestURL: URL
    private let fetcher: Fetcher

    /// 上次检查时间 —— actor 内部状态。caller 通常不需要直接管理；用 shouldCheck 判
    private var lastCheckedAt: Date?

    init(
        manifestURL: URL = UpdateChecker.defaultManifestURL,
        fetcher: Fetcher? = nil
    ) {
        self.manifestURL = manifestURL
        self.fetcher = fetcher ?? Self.defaultFetcher
    }

    /// 默认 fetcher —— URLSession.shared GET，10s timeout
    @Sendable
    private static func defaultFetcher(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    /// caller 调用决定是否要 GET（频控）—— 默认 24h 一次
    func shouldCheckNow(now: Date = Date()) -> Bool {
        guard let last = lastCheckedAt else { return true }
        return now.timeIntervalSince(last) >= Self.checkInterval
    }

    /// 主入口：拉 manifest 跟当前版本比，返回需要投递的 letter（如果有）。
    /// - currentVersion: app bundle 的 `CFBundleShortVersionString`
    /// - 返回 nil 表示：网络失败 / manifest 坏 / 版本不更新 / 系统版本太旧
    func check(currentAppVersion: String) async -> UpdateAvailableLetter? {
        lastCheckedAt = Date()

        guard let manifest = await fetchManifest() else { return nil }
        let m = manifest.latest

        // 版本对比
        guard Semver.compare(m.version, currentAppVersion) == .orderedDescending else {
            return nil  // 已是最新或老于当前
        }

        // 系统版本要求
        if let minVer = m.minimumSystemVersion {
            let osVer = ProcessInfo.processInfo.operatingSystemVersion
            let osStr = "\(osVer.majorVersion).\(osVer.minorVersion).\(osVer.patchVersion)"
            if Semver.compare(osStr, minVer) == .orderedAscending {
                return nil   // 系统太旧无法运行新版 —— 不推送，避免引导用户去下载装不上的版本
            }
        }

        return UpdateAvailableLetter(
            id: UUID(),
            version: m.version,
            releaseDate: m.releaseDate,
            detectedAt: Date(),
            readAt: nil,
            title: m.title,
            highlights: m.highlights,
            downloadURL: m.downloadURL,
            releaseNotesURL: m.releaseNotesURL
        )
    }

    // MARK: - 网络

    private func fetchManifest() async -> UpdateManifest? {
        guard let data = await fetcher(manifestURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
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
        return try? decoder.decode(UpdateManifest.self, from: data)
    }
}
