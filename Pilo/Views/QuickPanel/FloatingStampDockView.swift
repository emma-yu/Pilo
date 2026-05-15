import SwiftUI

/// 浮动邮票 dock 的 SwiftUI 内容（v6，2026-05-15 — AppKit drag + soft snap）。
///
/// **v6 重大重构**：
///   - **完全移除 SwiftUI `DragGesture`** —— drag 现在由 `FloatingDockHostingView`
///     在 AppKit 层用 `NSEvent.mouseLocation` 屏幕坐标驱动。SwiftUI 在
///     window-self-moving 场景下坐标系不可靠（v1-v5 反复修不好的根因）。
///   - **Icon 永远在 panel 正中**（110, 110）—— fan-out 几何（centerAngle + arcDegrees）
///     通过 `viewBox.fanOutGeometry` 动态计算：icon 四向都有空间→全圆 360°；
///     贴边→半圆 180° 朝屏幕内侧。最大邮票数也随之自适应（全圆 8 / 半圆 5）。
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
    /// **Stagger 真实驱动**：每个 orb 独立的可见 bool。Task 依次翻 true（入场）或 false（出场）。
    /// 不走 SwiftUI `.transition()` 因为 `.animation().delay()` 在 macOS 上 stagger 不稳定。
    @State private var orbVisibility: [Bool] = []
    @State private var fanOutAnimationTask: Task<Void, Never>?

    /// Fan-out 最大邮票数——根据几何模式自适应。
    ///
    /// **Why 自适应**：orb 视觉直径 36pt，半径 75pt 下不重叠的最小角间隔 ≈ 27.5°。
    ///   - 全圆 360°：360÷27.5 ≈ 13 上限；用 **8 邮票 + 1 "…" = 9 orbs**（40° 间距，疏朗）
    ///   - 半圆 180°：180÷27.5 ≈ 6 上限；用 **5 邮票 + 1 "…" = 6 orbs**（36° 间距，临界 OK）
    /// 用户把 icon 拖到屏幕中央可"解锁"更多 stamps。
    private var maxStampCount: Int {
        viewBox.fanOutGeometry.isFullCircle ? 8 : 5
    }

    private var stamps: [PromptStamp] {
        Array(appState.sidebarStamps.prefix(maxStampCount))
    }

    /// Icon 永远在 panel 正中（v6）
    private var iconCenter: CGPoint {
        CGPoint(x: 110, y: 110)
    }

    /// Toast 位置：
    ///   - 全圆模式：icon 上方 12 点钟外侧（offset 95，刚跳出 75pt orb 圈，不撞 orbs）
    ///   - 半圆模式：fan-out 反方向（朝屏幕内）—— 不挨 panel 边裁切
    private var toastPosition: CGPoint {
        let geom = viewBox.fanOutGeometry
        if geom.isFullCircle {
            let offset: CGFloat = 95
            return CGPoint(x: iconCenter.x, y: iconCenter.y - offset)
        } else {
            let offset: CGFloat = 60
            let radians = (geom.centerAngle + 180) * .pi / 180
            return CGPoint(
                x: iconCenter.x + offset * cos(radians),
                y: iconCenter.y + offset * sin(radians)
            )
        }
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

    // MARK: - Fan-out content（state-driven 动效，不走 SwiftUI .transition）

    private var fanOutContent: some View {
        ZStack {
            ForEach(Array(stamps.enumerated()), id: \.element.id) { i, stamp in
                stampOrb(stamp)
                    .position(orbPosition(for: i, total: stamps.count + 1))
                    .modifier(OrbAppearModifier(
                        visible: orbVisible(i),
                        tumbleRotation: orbTumbleRotation(i)
                    ))
                    .allowsHitTesting(isFanOut && orbVisible(i))
            }
            moreOrb
                .position(orbPosition(for: stamps.count, total: stamps.count + 1))
                .modifier(OrbAppearModifier(
                    visible: orbVisible(stamps.count),
                    tumbleRotation: orbTumbleRotation(stamps.count)
                ))
                .allowsHitTesting(isFanOut && orbVisible(stamps.count))

            if stamps.isEmpty {
                let geom = viewBox.fanOutGeometry
                // 全圆：hint 放 icon 下方；半圆：放 fan-out 反方向
                let hintPos: CGPoint = {
                    if geom.isFullCircle {
                        return CGPoint(x: iconCenter.x, y: iconCenter.y + 90)
                    } else {
                        let radians = (geom.centerAngle + 180) * .pi / 180
                        return CGPoint(
                            x: iconCenter.x + 90 * cos(radians),
                            y: iconCenter.y + 90 * sin(radians)
                        )
                    }
                }()
                Text(Copy.Stamps.quickPanelEmpty(appState.language))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 140)
                    .position(hintPos)
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

    // MARK: - 状态切换 + 真 stagger 动效调度
    //
    // **为什么不用 SwiftUI `.transition()`**：
    //   先前用 `.transition(...).animation(.spring(...).delay(stagger))` 在 macOS 上
    //   stagger 不稳定——`.delay()` 经常被 ambient `withAnimation` 上下文吞掉，或
    //   SwiftUI 把整个 view tree 插入视为单一 transaction，所有 orb 同时入场。
    //
    // **真 stagger 方案**：
    //   - 每个 orb 一个独立的 `orbVisibility[i]: Bool`（@State 数组）
    //   - 用 `Task { await Task.sleep(...) }` 依次翻 bool，每次 `withAnimation` 包住
    //   - 每个 bool 翻转独立触发 SwiftUI 动画——100% 物理可见的错峰

    private func toggleFanOut() {
        let newState = !isFanOut
        isFanOut = newState
        onFanOutChanged(newState)
        scheduleFanOutAnimation(show: newState)
    }

    private func collapse() {
        guard isFanOut else { return }
        isFanOut = false
        onFanOutChanged(false)
        scheduleFanOutAnimation(show: false)
    }

    private func collapseRequest() { collapse() }

    private func scheduleFanOutAnimation(show: Bool) {
        let total = stamps.count + 1
        fanOutAnimationTask?.cancel()
        fanOutAnimationTask = Task { @MainActor in
            if show {
                // 入场：reset 全 false → 每 60ms 翻一个 true（顺时针铺开）
                orbVisibility = Array(repeating: false, count: total)
                for i in 0..<total {
                    if Task.isCancelled { return }
                    if i > 0 {
                        try? await Task.sleep(nanoseconds: 60_000_000)  // 60ms
                    }
                    if Task.isCancelled { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        if i < orbVisibility.count { orbVisibility[i] = true }
                    }
                }
            } else {
                // 出场：每 35ms 反向翻一个 false（"信件次第回邮筒"）
                let currentCount = orbVisibility.count
                for j in 0..<currentCount {
                    if Task.isCancelled { return }
                    if j > 0 {
                        try? await Task.sleep(nanoseconds: 35_000_000)  // 35ms
                    }
                    if Task.isCancelled { return }
                    let idx = currentCount - 1 - j
                    withAnimation(.easeIn(duration: 0.18)) {
                        if idx < orbVisibility.count { orbVisibility[idx] = false }
                    }
                }
            }
        }
    }

    private func orbVisible(_ i: Int) -> Bool {
        i < orbVisibility.count ? orbVisibility[i] : false
    }

    /// 翻滚方向交替：偶数 -6°、奇数 +6°（"信件翻滚"语感，不机械）
    private func orbTumbleRotation(_ i: Int) -> Double {
        (i % 2 == 0) ? -6 : 6
    }

    // MARK: - 径向位置计算（自适应 360°/180°）

    private func orbPosition(for index: Int, total: Int) -> CGPoint {
        let radius: CGFloat = 75
        let geom = viewBox.fanOutGeometry
        let angle: CGFloat

        if geom.isFullCircle {
            // 全圆：360° ÷ total 均分，从 -90°（12 点钟）顺时针铺
            let angleStep = 360.0 / CGFloat(total)
            angle = -90 + CGFloat(index) * angleStep
        } else if total <= 1 {
            angle = geom.centerAngle
        } else {
            // 弧：endpoint 对齐，间距 arc / (total - 1)
            let startAngle = geom.centerAngle - geom.arcDegrees / 2
            let angleStep = geom.arcDegrees / CGFloat(total - 1)
            angle = startAngle + CGFloat(index) * angleStep
        }

        let radians = angle * .pi / 180
        let dx = radius * cos(radians)
        let dy = radius * sin(radians)
        return CGPoint(x: iconCenter.x + dx, y: iconCenter.y + dy)
    }
}

// MARK: - Orb 出/入场 ViewModifier
//
// **State-driven**：`visible: Bool` 决定显示/隐藏，三个变换合并：
//   - visible=true：scale 1，opacity 1，rotation 0
//   - visible=false：scale 0.25，opacity 0，rotation ±tumbleRotation
//
// 配合 `withAnimation` 包裹 `orbVisibility[i] = ...` 的翻转，SwiftUI 自动驱动
// 这些值的过渡。比 `.transition()` 可靠——bool 是单点状态，stagger 由 Task 调度。

private struct OrbAppearModifier: ViewModifier {
    let visible: Bool
    let tumbleRotation: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(visible ? 1.0 : 0.25, anchor: .center)
            .opacity(visible ? 1.0 : 0.0)
            .rotationEffect(.degrees(visible ? 0 : tumbleRotation))
    }
}
