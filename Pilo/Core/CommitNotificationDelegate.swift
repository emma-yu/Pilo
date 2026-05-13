import Foundation
import UserNotifications
import AppKit

/// UNUserNotificationCenter delegate —— 把"用户点了通知"翻译成应用动作。
///
/// 处理两种 banner：
///   - **commit 通知**（kind=commit）→ 调 `onCommitTap(repoId)`，选中 repo
///   - **letter 通知**（kind=dailyLetter/releaseLetter/updateLetter）→ 调 `onLetterTap()`，打开信箱
///
/// 用法：AppState 启动后实例化一个，set 给 UN center.delegate。
final class CommitNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// 用户点 commit 通知时回调（已 dispatch 到 MainActor）
    /// userInfo["repoId"] 对应 repo 的 UUID 字符串
    let onCommitTap: @MainActor (UUID) -> Void

    /// 用户点任意 letter 通知时回调（dailyLetter/releaseLetter/updateLetter 共用）
    /// v1: 都跳到信箱，user 从信箱选信打开
    let onLetterTap: @MainActor () -> Void

    init(
        onCommitTap: @escaping @MainActor (UUID) -> Void,
        onLetterTap: @escaping @MainActor () -> Void
    ) {
        self.onCommitTap = onCommitTap
        self.onLetterTap = onLetterTap
    }

    /// App 在前台时收到通知 —— 仍然弹 banner，避免"应用没开就没通知"造成困惑。
    /// 包含 `.list` 让通知也进入 Notification Center 历史，便于用户回看。
    /// **背景态时本方法不 fire**，banner 行为完全由 macOS 系统设置 +
    /// `content.interruptionLevel` 决定（`.timeSensitive` 强力推送）。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge])
    }

    /// 用户点了通知（或点 action button）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let info = response.notification.request.content.userInfo
        guard let kind = info["kind"] as? String else { return }

        // 把 userInfo 解析成 Sendable 值后再跳 MainActor，避免 strict-concurrency 警告
        let repoId: UUID? = {
            guard let s = info["repoId"] as? String else { return nil }
            return UUID(uuidString: s)
        }()

        Task { @MainActor [onCommitTap, onLetterTap] in
            // 把主窗口拉到前台 —— 通知点击不会自动激活 menu bar 应用
            NSApp.activate(ignoringOtherApps: true)
            switch kind {
            case "commit":
                if let repoId { onCommitTap(repoId) }
            case "dailyLetter", "releaseLetter", "updateLetter":
                onLetterTap()
            default:
                break
            }
        }
    }
}
