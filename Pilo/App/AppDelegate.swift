import AppKit

/// Pilo 的 NSApplicationDelegate ——挂载 OS-level 生命周期对象。
///
/// 当前职责：
///   - `FloatingStampDockController`：屏幕边缘浮动邮票 icon 的生命周期管家
///
/// 通过 `.floatingStampDockToggled` notification 跟 AppState 解耦——
/// 任何地方（菜单栏 / 右键菜单 / Settings 等）调 `appState.setFloatingStampDockVisible(_:)`
/// 都会 post notification，AppDelegate 监听做 show/hide。
///
/// `@unchecked Sendable`：所有方法都在 main thread 调用（NSApplicationDelegate 约定），
/// NotificationCenter 闭包用 `queue: .main`。Swift 6 strict concurrency 下的标准模式。
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {

    private var floatingDockController: FloatingStampDockController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        observeDockToggle()
        syncDockVisibilityOnStartup()
    }

    /// 启动时显式拉一次 visibility——补 AppState.init defer post 的通知（彼时
    /// AppDelegate 还没注册观察者，通知发给空气，导致勾选了但 icon 不显示，必须
    /// 手动 toggle off→on 才能看到的 bug）。
    ///
    /// 直接读 UserDefaults：是 SSOT，且永远 ready（不依赖 AppState.shared 是否设置）。
    private func syncDockVisibilityOnStartup() {
        let visible = UserDefaults.standard.bool(forKey: SettingsKey.floatingStampDockVisible.rawValue)
        guard visible else { return }
        Task { @MainActor [weak self] in
            self?.updateDockVisibility(true)
        }
    }

    /// 监听 floating dock visibility 切换。
    /// 由 AppState.setFloatingStampDockVisible 触发；
    /// AppState.init 完成时也 post 一次（初始状态恢复）。
    private func observeDockToggle() {
        NotificationCenter.default.addObserver(
            forName: .floatingStampDockToggled,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let visible = (notification.object as? Bool) ?? false
            Task { @MainActor [weak self] in
                self?.updateDockVisibility(visible)
            }
        }
    }

    @MainActor
    private func updateDockVisibility(_ visible: Bool) {
        guard let appState = AppState.shared else {
            NSLog("[AppDelegate] dock toggle 收到但 AppState.shared 未 ready")
            return
        }

        if visible {
            if floatingDockController == nil {
                floatingDockController = FloatingStampDockController(appState: appState)
            }
            floatingDockController?.show()
        } else {
            floatingDockController?.hide()
        }
    }
}
