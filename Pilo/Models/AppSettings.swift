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

    // S3 Identity Sentinel —— 每类 RepoCategory 绑一个 git user.email
    case identityWork
    case identityPersonal
    case identityExperiment

    /// 用户在信件里被称呼的名字。空则 fallback 到 git config user.name，再 fallback 到 "朋友"
    case userDisplayName

    /// Commit 通知（macOS 推送）。默认 OFF，opt-in only —— 避免用户首次使用就被通知轰炸
    case enableCommitNotifications

    /// 邮局音效。默认 OFF —— productivity app 静音是 macOS 惯例（Bear/Things/Reeder 都没）
    case enableSoundEffects

    /// 浮动邮票 dock icon 是否显示。默认 OFF —— opt-in。
    /// 用户通过菜单栏「邮票本召唤」行 toggle，AppDelegate 监听
    /// `.floatingStampDockToggled` notification 做 show/hide。
    case floatingStampDockVisible

    /// 浮动 icon 的水平比例 0.0-1.0（0=icon 贴左 1=icon 贴右）。默认 1.0。
    /// **v8 起自由摆放**：无 snap，用户拖哪松手就停哪，仅 clamp 在屏幕内防消失。
    /// 比例基于 icon 屏幕坐标在 `[visibleFrame.minX+22, maxX-22]` 内的位置。
    case floatingStampDockXRatio

    /// 浮动 icon 的垂直比例 0.0-1.0（0=icon 贴顶 1=icon 贴底）。默认 0.5。
    case floatingStampDockYRatio
}

enum AppSettingsDefaults {
    static let fetchIntervalMinutes = 15
    static let dailyNotificationLimit = 3
    static let tone: Tone = .friendly
}

extension Notification.Name {
    /// 浮动 dock icon visibility 切换。`object` 是新的 Bool 值。
    /// AppDelegate 监听做 FloatingStampDockController 的 show / hide。
    static let floatingStampDockToggled = Notification.Name("dev.pilo.floatingStampDockToggled")
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
