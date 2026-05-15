import AppKit
import SwiftUI

/// 自定义 NSPanel —— borderless + nonactivatingPanel 组合默认 `canBecomeKey = false`，
/// 会导致 panel "创建成功但不显示 / 不响应事件"。这个子类显式覆写为 true，
/// 同时保证 `canBecomeMain = false`（不抢主窗口身份）。
final class FloatingStampPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// **v7 起返回 rect 不变**——允许 panel 部分溢出屏幕。原因：浮动 dock 的 icon
    /// 视觉锚点在 panel 正中，panel 大部分区域透明；为了让 icon 能贴到屏幕实际
    /// 边缘，panel 必须能溢出 visibleFrame。我们在 controller 层基于 icon 屏幕
    /// 坐标做 clamping，AppKit 这层放权。
    ///
    /// Phase 1 StampQuickPanelController 始终居中弹出，不会触发到边缘溢出场景，
    /// 所以这里全局放权也安全。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

/// 全局邮票召唤面板的生命周期管家。
///
/// 设计要点：
///   - **`.nonactivatingPanel`**：用户按 ⌘⇧Y 召唤时焦点**不离开当前 app**——
///     这是整个 feature 的关键。Pilo 不能偷焦，否则用户按完 ⌘V 粘到 Pilo 自己
///   - **`canBecomeKey = true`（subclass override）**：borderless panel 必须显式 override，
///     否则不显示
///   - **`.floating` level + `.canJoinAllSpaces`**：面板在所有 Space / 全屏 app 上方可见
///   - **居中 active screen**：始终在主屏幕中央，Phase 1 不支持位置记忆
///   - **点击 panel 外区域自动关**：全局鼠标监听（不需要 Accessibility 权限）
///
/// 由 AppDelegate 持有，lazy init 在首次 hotkey 触发时。
@MainActor
final class StampQuickPanelController {

    private weak var appState: AppState?
    private var panel: FloatingStampPanel?
    private var globalClickMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let appState else { return }

        let panel = ensurePanel(appState: appState)
        centerOnScreen(panel: panel)
        panel.orderFrontRegardless()  // 关键：show without stealing focus
        installClickOutsideMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeClickOutsideMonitor()
    }

    // MARK: - Panel building

    private func ensurePanel(appState: AppState) -> FloatingStampPanel {
        if let existing = panel { return existing }

        let p = FloatingStampPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.animationBehavior = .utilityWindow

        // SwiftUI content —— 用默认 autoresizing，让 NSHostingView 跟着 panel content frame
        let content = StampQuickPanelView(
            appState: appState,
            onDismiss: { [weak self] in self?.hide() }
        )
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 320)
        host.autoresizingMask = [.width, .height]
        p.contentView = host

        self.panel = p
        return p
    }

    private func centerOnScreen(panel: FloatingStampPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let panelFrame = panel.frame
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2 + 60  // 略偏上，符合视觉重心
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Click-outside monitor

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
