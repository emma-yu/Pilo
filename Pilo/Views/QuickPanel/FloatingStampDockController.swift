import AppKit
import SwiftUI

/// 浮动邮票 dock 的生命周期管家。
///
/// **核心架构（v8，2026-05-15 — 完全自由摆放，无 snap）**：
///
/// **Drag tracking 完全在 AppKit 层**（`FloatingDockHostingView` 的 mouseDown/Dragged/Up
/// override）—— 用 `NSEvent.mouseLocation` 的**真·屏幕坐标**，绕过 SwiftUI
/// DragGesture。原因：SwiftUI 的 `.local` 和 `.global` 在 macOS 上都是 window 相对，
/// 当 window 自己被搬动时坐标系全错（v1-v5 反复修不好的根因）。
///
/// **无 snap（v8 终态）**：用户拖哪松手就停哪。唯一约束是 icon 中心 clamp 在
/// `[visibleFrame.minX+22, maxX-22]` × `[minY+22, maxY-22]` 之间（icon 边缘恰好贴
/// 屏幕边缘 = 最大允许），保证不消失。v6/v7 的 edge snap 反 UX —— 这是用户的邮票本，
/// 自主权 > 视觉整齐。"snap 是系统的便利，不是用户的便利。"
///
/// **位置持久化**：`floatingStampDockXRatio` + `floatingStampDockYRatio`，基于
/// **icon 屏幕坐标**比例（不是 panel），多分辨率友好。
///
/// **Fan-out 方向**：动态计算 —— icon 在屏幕右半 → 向左展开；左半 → 向右展开。
@MainActor
final class FloatingStampDockController {

    private weak var appState: AppState?
    private var panel: FloatingStampPanel?
    private var hostingView: FloatingDockHostingView<FloatingStampDockView>?
    private var fullPanelController: StampQuickPanelController?

    private var isFanOutActive: Bool = false {
        didSet {
            hostingView?.fanOutActive = isFanOutActive
            if isFanOutActive {
                installOutsideClickMonitor()
            } else {
                removeOutsideClickMonitor()
            }
        }
    }

    private var globalClickMonitor: Any?
    private weak var dockViewBox: FloatingDockViewBox?

    static let panelSize: CGFloat = 220
    /// Icon 在 panel 内的中心偏移（icon 视觉中心永远在 panel 正中）
    static let iconCenterInPanelOffset: CGFloat = panelSize / 2  // 110
    /// Icon 视觉半径（44pt icon → 22pt half）—— 用作 clamp 边界（icon 边缘最多贴屏幕边）
    static let iconHalfSize: CGFloat = 22

    /// Icon 中心在屏幕上的允许范围（icon 边缘不超出 visibleFrame）
    static func iconScreenXRange(visibleFrame: NSRect) -> (min: CGFloat, max: CGFloat) {
        (visibleFrame.minX + iconHalfSize, visibleFrame.maxX - iconHalfSize)
    }

    static func iconScreenYRange(visibleFrame: NSRect) -> (min: CGFloat, max: CGFloat) {
        (visibleFrame.minY + iconHalfSize, visibleFrame.maxY - iconHalfSize)
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    func show() {
        guard let appState else { return }
        let panel = ensurePanel(appState: appState)
        positionPanelFromSavedState(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        isFanOutActive = false
        dockViewBox?.requestCollapse()
        panel?.orderOut(nil)
    }

    func openFullPanel() {
        guard let appState else { return }
        if fullPanelController == nil {
            fullPanelController = StampQuickPanelController(appState: appState)
        }
        fullPanelController?.show()
    }

    // MARK: - Fan-out state callback (from view)

    func setFanOutMode(_ isFanOut: Bool) {
        isFanOutActive = isFanOut
    }

    // MARK: - Drag end callback (from hostingView AppKit handler)

    fileprivate func handleDragEnded() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        // **v8 无 snap**：icon 在 onDragChanged 期间已 clamp 到屏幕合法范围，
        // mouseUp 时位置就是最终位置。仅持久化 + 同步 fan-out 方向。
        persistPosition(panel: panel, screen: screen)
        dockViewBox?.updateFanOutGeometry(computeFanOutGeometry(panel: panel, screen: screen))
    }

    /// 拖动期间 clamp panel 位置：保证 icon 边缘不超出 visibleFrame
    fileprivate func applyDragPosition(desired: NSPoint) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let iconOffset = Self.iconCenterInPanelOffset
        let (minIconX, maxIconX) = Self.iconScreenXRange(visibleFrame: frame)
        let (minIconY, maxIconY) = Self.iconScreenYRange(visibleFrame: frame)

        let desiredIconX = desired.x + iconOffset
        let desiredIconY = desired.y + iconOffset

        let clampedIconX = min(max(desiredIconX, minIconX), maxIconX)
        let clampedIconY = min(max(desiredIconY, minIconY), maxIconY)

        panel.setFrameOrigin(NSPoint(
            x: clampedIconX - iconOffset,
            y: clampedIconY - iconOffset
        ))
    }

    fileprivate func handleIconTapped() {
        dockViewBox?.requestToggle()
    }

    // MARK: - Panel building

    private func ensurePanel(appState: AppState) -> FloatingStampPanel {
        if let existing = panel { return existing }

        let p = FloatingStampPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelSize, height: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.animationBehavior = .utilityWindow

        let viewBox = FloatingDockViewBox()
        // 初始 geometry 用默认 360°——positionPanelFromSavedState 会马上根据 saved 位置 update

        let content = FloatingStampDockView(
            appState: appState,
            viewBox: viewBox,
            onOpenFullPanel: { [weak self] in self?.openFullPanel() },
            onFanOutChanged: { [weak self] isFanOut in self?.setFanOutMode(isFanOut) }
        )
        let host = FloatingDockHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: Self.panelSize, height: Self.panelSize)
        host.autoresizingMask = [.width, .height]
        host.iconRect = Self.iconHitRect()
        host.fanOutActive = false

        // AppKit drag wiring：用 NSEvent.mouseLocation 真屏幕坐标
        host.onDragChanged = { [weak self, weak host] delta in
            guard let self, let host, let dragStart = host.dragStartPanelOrigin else { return }
            let desired = NSPoint(x: dragStart.x + delta.x, y: dragStart.y + delta.y)
            // **v7 关键**：clamp 基于 icon 屏幕坐标（保证 icon 能贴到屏幕实际边缘）
            self.applyDragPosition(desired: desired)
        }
        host.onDragEnded = { [weak self] in
            self?.handleDragEnded()
        }
        host.onIconTapped = { [weak self] in
            self?.handleIconTapped()
        }
        host.onDragStarted = { [weak self] in
            // 拖动开始时 collapse fan-out（如果展开了）
            self?.dockViewBox?.requestCollapse()
        }

        p.contentView = host

        self.panel = p
        self.hostingView = host
        self.dockViewBox = viewBox
        return p
    }

    private func positionPanelFromSavedState(_ panel: FloatingStampPanel) {
        guard let screen = NSScreen.main else { return }
        panel.setFrameOrigin(computePanelOrigin(screen: screen))
        dockViewBox?.updateFanOutGeometry(computeFanOutGeometry(panel: panel, screen: screen))
    }

    private func computePanelOrigin(screen: NSScreen) -> NSPoint {
        let frame = screen.visibleFrame
        let iconOffset = Self.iconCenterInPanelOffset
        let (minIconX, maxIconX) = Self.iconScreenXRange(visibleFrame: frame)
        let (minIconY, maxIconY) = Self.iconScreenYRange(visibleFrame: frame)

        let xRatio = readXRatio()
        let yRatio = readYRatio()

        // **v7 icon-based**：xRatio 0=icon 贴左，1=icon 贴右；yRatio 0=icon 贴顶，1=icon 贴底
        let iconX = minIconX + xRatio * (maxIconX - minIconX)
        let iconY = maxIconY - yRatio * (maxIconY - minIconY)

        return NSPoint(x: iconX - iconOffset, y: iconY - iconOffset)
    }

    private func persistPosition(panel: NSWindow, screen: NSScreen) {
        let frame = screen.visibleFrame
        let iconOffset = Self.iconCenterInPanelOffset
        let (minIconX, maxIconX) = Self.iconScreenXRange(visibleFrame: frame)
        let (minIconY, maxIconY) = Self.iconScreenYRange(visibleFrame: frame)

        let iconX = panel.frame.origin.x + iconOffset
        let iconY = panel.frame.origin.y + iconOffset

        let xRange = maxIconX - minIconX
        let xRatio = xRange > 0
            ? Double((iconX - minIconX) / xRange).clamped(0, 1)
            : 1.0

        let yRange = maxIconY - minIconY
        let yRatio = yRange > 0
            ? Double((maxIconY - iconY) / yRange).clamped(0, 1)
            : 0.5

        UserDefaults.standard.set(xRatio, forKey: SettingsKey.floatingStampDockXRatio.rawValue)
        UserDefaults.standard.set(yRatio, forKey: SettingsKey.floatingStampDockYRatio.rawValue)
    }

    private func readXRatio() -> CGFloat {
        if UserDefaults.standard.object(forKey: SettingsKey.floatingStampDockXRatio.rawValue) == nil {
            return 1.0  // 默认右边缘
        }
        return CGFloat(UserDefaults.standard.double(forKey: SettingsKey.floatingStampDockXRatio.rawValue))
    }

    private func readYRatio() -> CGFloat {
        if UserDefaults.standard.object(forKey: SettingsKey.floatingStampDockYRatio.rawValue) == nil {
            return 0.5
        }
        return CGFloat(UserDefaults.standard.double(forKey: SettingsKey.floatingStampDockYRatio.rawValue))
    }

    /// Fan-out 几何——根据 icon 与屏幕四边的距离自适应。
    ///
    /// **规则**（orbReach = radius 75 + orb 半径 20 = **95pt** 安全距离）：
    ///   1. icon 距四边都 ≥ orbReach → **全圆 360°**（centerAngle 不重要）
    ///   2. 否则 → **半圆 180°**，centerAngle 指向"最近边的反方向"
    ///
    /// 这样 icon 拖到屏幕中央会得到完整 360° 邮票环；贴边时降级到半圆朝屏幕内侧。
    private func computeFanOutGeometry(panel: NSWindow, screen: NSScreen) -> FanOutGeometry {
        let frame = screen.visibleFrame
        let iconX = panel.frame.origin.x + Self.iconCenterInPanelOffset
        let iconY = panel.frame.origin.y + Self.iconCenterInPanelOffset
        let orbReach: CGFloat = 95

        let distLeft = iconX - frame.minX
        let distRight = frame.maxX - iconX
        let distBottom = iconY - frame.minY      // AppKit Y bottom-origin
        let distTop = frame.maxY - iconY         // distTop 大 = icon 离屏幕顶远

        let minDist = min(distLeft, distRight, distTop, distBottom)
        if minDist >= orbReach {
            return FanOutGeometry(centerAngle: 0, arcDegrees: 360)
        }

        // 找最近的边 → 朝反方向开。坐标系约定（跟 orbPosition 一致）：
        // 0°=右，90°=下（SwiftUI Y+），180°=左，270°=上（SwiftUI Y-）
        let centerAngle: CGFloat
        if minDist == distLeft {
            centerAngle = 0      // 最近左边 → 朝右开
        } else if minDist == distRight {
            centerAngle = 180    // 最近右边 → 朝左开
        } else if minDist == distTop {
            centerAngle = 90     // 最近顶边 → 朝下开（SwiftUI Y+ = 屏幕下）
        } else {
            centerAngle = 270    // 最近底边 → 朝上开
        }
        return FanOutGeometry(centerAngle: centerAngle, arcDegrees: 180)
    }

    // MARK: - Outside click monitor

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dockViewBox?.requestCollapse()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // MARK: - Constants

    /// Icon 在 panel 内的视觉中心（**v6 起永远在 panel 正中**）
    static let iconCenterInPanel: CGPoint = CGPoint(x: panelSize / 2, y: panelSize / 2)

    static func iconHitRect() -> NSRect {
        let hitSize: CGFloat = 56
        return NSRect(
            x: iconCenterInPanel.x - hitSize / 2,
            y: iconCenterInPanel.y - hitSize / 2,
            width: hitSize,
            height: hitSize
        )
    }
}

// MARK: - NSHostingView subclass：AppKit-level drag tracking + selective click-through

/// 自定义 NSHostingView，负责：
///   1. **Click-through hitTest**：idle 时只有 icon 区域接受 click，透明区域穿透下层 app
///   2. **AppKit drag tracking**：mouseDown / Dragged / Up 完全在这里处理，
///      用 `NSEvent.mouseLocation` 真屏幕坐标驱动 window 移动 —— 绕开 SwiftUI 坐标系
///      在 window 自移场景下失效的根本问题（v1-v5 反复折腾的根因）
///
/// **关键设计**：当 click 落在 iconRect 内、且非 fan-out 状态时，hitTest **返回 self**
/// 而非 super —— 这样 AppKit 把 mouseDown 直接送给我们，不让 SwiftUI 截胡。然后我们
/// 在 mouseDragged 里基于屏幕坐标 delta 移动 window；mouseUp 时按是否曾 drag 过决定
/// 是触发 tap 回调（→ toggle fan-out）还是 drag end 回调（→ soft snap）。
final class FloatingDockHostingView<Content: View>: NSHostingView<Content> {

    var iconRect: NSRect = .zero
    var fanOutActive: Bool = false

    /// Mouse down 时的屏幕坐标（真·screen coords）
    private var mouseDownScreenPoint: NSPoint?
    /// Mouse down 时的 panel origin（screen coords）
    var dragStartPanelOrigin: NSPoint?
    /// 是否已超过 5px 阈值，从 click 升级到 drag
    private var hasStartedDrag: Bool = false

    /// 拖动开始（≥5px 时触发一次）
    var onDragStarted: (() -> Void)?
    /// 拖动中（delta = 屏幕坐标 cursor 当前位置 - 起始位置）
    var onDragChanged: ((NSPoint) -> Void)?
    /// 拖动结束（mouseUp 时若曾进入 drag 模式）
    var onDragEnded: (() -> Void)?
    /// Icon 被点击（mouseUp 时若未进入 drag 模式 且 mouseDown 在 iconRect）
    var onIconTapped: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Fan-out 状态：让 SwiftUI 内部正常处理（stamp button / 空白处 Color.clear tap）
        if fanOutActive {
            return super.hitTest(point)
        }

        let localPoint = convert(point, from: superview)

        // Icon 区域：**返回 self**，强制 AppKit 把 mouseDown 送到我们这里
        // （由我们决定 click → fan-out toggle 还是 drag → 移 window）
        if iconRect.contains(localPoint) {
            return self
        }

        // 透明区域：穿透到下层 app
        return nil
    }

    // MARK: - AppKit mouse handlers
    //
    // **关键约束（v8.1 修复 click-eating bug）**：仅在 `fanOutActive == false`
    // 且 click 落在 iconRect 时，我们才接管 mouseDown/Dragged/Up 来实现
    // "click=toggle / drag=移 window" 的二分。fan-out 展开后**所有事件**必须
    // forward 到 super，让 SwiftUI 把 click 送到 stamp Button / 更多 Button /
    // 空白处 Color.clear tap catcher 去处理。
    //
    // v6 引入这些 override 时漏了"fan-out 展开后必须放手"——导致 fan-out 期间
    // 的 click 被我们截下来 → SwiftUI Button 永远收不到 → 邮票复制 / 更多 panel
    // 全失效。

    override func mouseDown(with event: NSEvent) {
        if fanOutActive {
            super.mouseDown(with: event)
            return
        }
        mouseDownScreenPoint = NSEvent.mouseLocation
        dragStartPanelOrigin = window?.frame.origin
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        if fanOutActive {
            super.mouseDragged(with: event)
            return
        }
        guard let start = mouseDownScreenPoint else {
            super.mouseDragged(with: event)
            return
        }
        let now = NSEvent.mouseLocation
        let delta = NSPoint(x: now.x - start.x, y: now.y - start.y)

        if !hasStartedDrag {
            // 5px 阈值：超过才算 drag（避免抖手指误触）
            if hypot(delta.x, delta.y) > 5 {
                hasStartedDrag = true
                onDragStarted?()
            } else {
                return
            }
        }

        onDragChanged?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        if fanOutActive {
            super.mouseUp(with: event)
            return
        }
        defer {
            mouseDownScreenPoint = nil
            dragStartPanelOrigin = nil
            hasStartedDrag = false
        }

        if hasStartedDrag {
            onDragEnded?()
        } else {
            // 没拖动 → 是 click → toggle fan-out
            onIconTapped?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // 让 SwiftUI 的 .contextMenu 处理
        super.rightMouseDown(with: event)
    }
}

// MARK: - Fan-out 几何（自适应 360°/180°）

/// Fan-out 弧形几何配置。Controller 根据 icon 屏幕位置算出来交给 view 用。
///
/// - `arcDegrees == 360`：全圆模式，orbs 在 360° 上均分（angleStep = 360/total）
/// - `arcDegrees < 360`：弧模式，orbs 在 [center - arc/2, center + arc/2] 上 endpoint 对齐
/// - `centerAngle` 坐标约定（与 `orbPosition` 一致）：
///   - 0° = 右（cos+），90° = 下（SwiftUI Y+），180° = 左，270° = 上
struct FanOutGeometry: Equatable {
    var centerAngle: CGFloat = 0
    var arcDegrees: CGFloat = 360

    var isFullCircle: Bool { arcDegrees >= 360 }
}

// MARK: - View-Controller 通信 Box

/// View 暴露给 Controller 的指令通道。
/// - `requestCollapse`：关 fan-out（点 panel 外 / 拖动开始 / 隐藏 dock）
/// - `requestToggle`：切换 fan-out（icon 被 AppKit-level click 命中）
/// - `fanOutGeometry` / `updateFanOutGeometry`：fan-out 弧形几何
@MainActor
final class FloatingDockViewBox: ObservableObject {
    var collapseRequested: (() -> Void)?
    var toggleRequested: (() -> Void)?
    @Published var fanOutGeometry = FanOutGeometry()

    func requestCollapse() { collapseRequested?() }
    func requestToggle() { toggleRequested?() }
    func updateFanOutGeometry(_ geom: FanOutGeometry) {
        if fanOutGeometry != geom {
            fanOutGeometry = geom
        }
    }
}

// MARK: - Util

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double {
        min(max(self, lo), hi)
    }
}
