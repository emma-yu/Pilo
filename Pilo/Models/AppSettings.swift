import Foundation
import SwiftUI

/// UserDefaults 键名集中处。视图层用 `@AppStorage(SettingsKey.x.rawValue)` 引用。
enum SettingsKey: String {
    case hasCompletedOnboarding
    case tone
    case language                 // .zh / .en
    case watchDirectoryPaths      // [String] — 编码成 JSON 后存
    case fetchIntervalMinutes
    case enableSecretScan
    case enableCommitGuard
    case enableMainBranchWarning
    case killSwitchEnabled
    case killSwitchExpiresAt
    case dailyNotificationLimit
    case notifyOnNetworkRecover
    case notifyOnPushComplete
    case notifyOnStaleRepo
    case theme
    case reduceMotion             // .system / .on / .off
}

enum AppSettingsDefaults {
    static let fetchIntervalMinutes = 15
    static let dailyNotificationLimit = 3
    static let tone: Tone = .friendly
}

/// Watch directory 列表使用 JSON 编码进 UserDefaults，避免和 NSArray 的类型边界纠缠。
enum WatchDirectoriesStorage {
    static func load() -> [URL] {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKey.watchDirectoryPaths.rawValue),
              let data = raw.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    static func save(_ urls: [URL]) {
        let paths = urls.map(\.path)
        guard let data = try? JSONEncoder().encode(paths),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: SettingsKey.watchDirectoryPaths.rawValue)
    }
}
