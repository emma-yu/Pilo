import SwiftUI

/// 浮动邮票 dock 的 SwiftUI 内容（v6，2026-05-15 — AppKit drag + soft snap）。
///
/// **v6 重大重构**：
///   - **完全移除 SwiftUI `DragGesture`** —— drag 现在由 `FloatingDockHostingView`
///     在 AppKit 层用 `NSEvent.mouseLocation` 屏幕坐标驱动。SwiftUI 在
///     window-self-moving 场景下坐标系不可靠（v1-v5 反复修不好的根因）。
///   - **Icon 永远在 panel 正中**（110, 110）—— fan-out 方向通过
///     `viewBox.fanOutOpensLeft` 动态切换，不再绑死 edge。
///   - **Tap 触发分两路**：
///       - fan-out OFF 时：AppKit hostingView 截 mouseDown → onIconTapped 回调
///         → controller → viewBox.requestToggle → 这里的 toggleFanOut
///       - fan-out ON 时：SwiftUI hitTest 正常下钻 → 这里的 `.onTapGesture` 触发
///   - **Inline toast**：复制后 icon 旁边渲染 capsule "✓ 已誊抄"
struct FloatingStampDockView: View {

    let appState: AppState
    @ObservedObject var viewBox: FloatingDockViewBox
    let onOpenFullPanel: () -> Void
    let onFanOutChanged: (Bool) -> Void

    @State private var isFanOut = false
    @State private var justCopiedStampId: UUID?
    @State private var showCopiedToast = false
    @State private var toastTask: Task<Void, Never>?

    private var stamps: [PromptStamp] { Array(appState.sidebarStamps.prefix(6)) }

    /// Icon 永远在 panel 正中（v6）
    private var iconCenter: CGPoint {
        CGPoint(x: 110, y: 110)
    }

    /// Toast 位置（v8.2 修裁剪）：朝**屏幕内侧**放，不是朝 fan-out 反方向。
    ///
    /// 原 v6 逻辑朝 fan-out 反方向 → 当 icon 拖到屏幕边缘时 toast 顶到 panel
    /// 边界被裁。Toast 出现时 fan-out 已收起，根本不会重叠，所以 toast 应朝
    /// 屏幕内侧（有空间那侧）放才对。
    ///
    /// - `fanOutOpensLeft=true`（icon 在右半屏）→ toast 在 icon 左侧（朝屏幕内）
    /// - `fanOutOpensLeft=false`（icon 在左半屏）→ toast 在 icon 右侧（朝屏幕内）
    ///
    /// offset 60pt：toast ~70pt 宽，半宽 ~35pt，60+35=95 < panel 半宽 110pt
    /// → 留 15pt 安全 margin，再也不被 panel 边界裁。
    private var toastPosition: CGPoint {
        let offset: CGFloat = 60
        return CGPoint(
            x: iconCenter.x + (viewBox.fanOutOpensLeft ? -offset : offset),
            y: iconCenter.y
        )
    }

    var body: some View {
        ZStack {
            // Fan-out 状态的空白区域点击 catcher（点空白处收拢）
            if isFanOut {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { collapse() }
            }

            if isFanOut {
                fanOutContent
            }

            // 主 icon
            iconView
                .position(iconCenter)

            if showCopiedToast {
                copiedToastView
                    .position(toastPosition)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 220, height: 220)
        .contextMenu {
            Button {
                appState.setFloatingStampDockVisible(false)
            } label: {
                Label(Copy.menubarQuickStampsHide(appState.language),
                      systemImage: "eye.slash")
            }
        }
        .onAppear {
            // 注入控制接口给 controller（外部 click monitor / AppKit tap 回调走这里）
            viewBox.collapseRequested = { collapseRequest() }
            viewBox.toggleRequested = { toggleFanOut() }
        }
    }

    // MARK: - Icon

    private var iconView: some View {
        Image("PostalStamp")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .opacity(0.92)
            .rotationEffect(.degrees(isFanOut ? 0 : -4))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFanOut)
            // **重要**：仅 fan-out ON 时挂 tap gesture（fan-out OFF 时由 AppKit 截胡，
            // 通过 viewBox.toggleRequested 进来）。这里挂 tap 让用户在 fan-out 展开后
            // 点 icon 也能关闭。
            .onTapGesture {
                if isFanOut { toggleFanOut() }
            }
    }

    // MARK: - Copied toast

    private var copiedToastView: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.stampMint)
            Text(toastLabelText)
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.piloPaper)
                .overlay(
                    Capsule().stroke(Color.piloGoldDark.opacity(0.4), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 1)
    }

    private var toastLabelText: String {
        appState.language == .zh ? "已誊抄" : "Copied"
    }

    // MARK: - Fan-out content

    private var fanOutContent: some View {
        ZStack {
            ForEach(Array(stamps.enumerated()), id: \.element.id) { i, stamp in
                stampOrb(stamp)
                    .position(orbPosition(for: i, total: stamps.count + 1))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            moreOrb
                .position(orbPosition(for: stamps.count, total: stamps.count + 1))
                .transition(.scale(scale: 0.4).combined(with: .opacity))

            if stamps.isEmpty {
                Text(Copy.Stamps.quickPanelEmpty(appState.language))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 140)
                    .position(
                        x: iconCenter.x + (viewBox.fanOutOpensLeft ? -90 : 90),
                        y: iconCenter.y
                    )
            }
        }
    }

    private func stampOrb(_ stamp: PromptStamp) -> some View {
        Button {
            handleStampClick(stamp)
        } label: {
            ZStack {
                PromptStampChip(stamp: stamp, size: .compact)
                if justCopiedStampId == stamp.id {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.stampMint)
                }
            }
        }
        .buttonStyle(.plain)
        .help(stamp.title.isEmpty ? String(stamp.body.prefix(60)) : stamp.title)
    }

    private var moreOrb: some View {
        Button {
            collapse()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onOpenFullPanel()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.piloPaper)
                    .overlay(Circle().stroke(Color.piloGoldDark.opacity(0.5), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.piloGoldDark)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .help("更多 …")
    }

    // MARK: - 点击邮票 → 复制 + inline toast + 收拢

    private func handleStampClick(_ stamp: PromptStamp) {
        justCopiedStampId = stamp.id
        appState.pasteStamp(stamp, emitToast: false)

        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showCopiedToast = false
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            collapse()
            justCopiedStampId = nil
        }
    }

    // MARK: - 状态切换

    private func toggleFanOut() {
        let newState = !isFanOut
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isFanOut = newState
        }
        onFanOutChanged(newState)
    }

    private func collapse() {
        guard isFanOut else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isFanOut = false
        }
        onFanOutChanged(false)
    }

    private func collapseRequest() {
        guard isFanOut else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isFanOut = false
        }
        onFanOutChanged(false)
    }

    // MARK: - 径向位置计算（方向跟随 viewBox.fanOutOpensLeft）

    private func orbPosition(for index: Int, total: Int) -> CGPoint {
        let radius: CGFloat = 75
        let arcDegrees: CGFloat = 150
        // fan-out 向左 → centerAngle 180（向 -x 方向）；向右 → 0
        let centerAngle: CGFloat = viewBox.fanOutOpensLeft ? 180 : 0

        let startAngle = centerAngle - arcDegrees / 2

        let angle: CGFloat
        if total <= 1 {
            angle = centerAngle
        } else {
            let angleStep = arcDegrees / CGFloat(total - 1)
            angle = startAngle + CGFloat(index) * angleStep
        }

        let radians = angle * .pi / 180
        let dx = radius * cos(radians)
        let dy = radius * sin(radians)
        return CGPoint(x: iconCenter.x + dx, y: iconCenter.y + dy)
    }
}
