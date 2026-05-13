import Foundation
import UserNotifications
import AppKit

/// UNUserNotificationCenter delegate —— 把"用户点了一条 commit 通知"翻译成
/// 「打开 Pilo 主窗 + 选中对应 repo」的应用动作。
///
/// 用法：AppState 启动后实例化一个，set 给 UN center.delegate；
/// 通过 onCommitTap 闭包回到 MainActor 操作 AppState。
final class CommitNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// 用户点通知时回调（已 dispatch 到 MainActor）
    /// userInfo["repoId"] 对应 repo 的 UUID 字符串
    let onCommitTap: @MainActor (UUID) -> Void

    init(onCommitTap: @escaping @MainActor (UUID) -> Void) {
        self.onCommitTap = onCommitTap
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
        guard let kind = info["kind"] as? String, kind == "commit" else { return }
        guard let repoIdStr = info["repoId"] as? String,
              let repoId = UUID(uuidString: repoIdStr) else { return }

        let cb = self.onCommitTap
        Task { @MainActor in
            // 把主窗口拉到前台 —— 通知点击不会自动激活 menu bar 应用
            NSApp.activate(ignoringOtherApps: true)
            cb(repoId)
        }
    }
}
