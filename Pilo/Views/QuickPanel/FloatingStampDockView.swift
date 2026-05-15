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

    // MARK: - Fan-out content

    private var fanOutContent: some View {
        ZStack {
            ForEach(Array(stamps.enumerated()), id: \.element.id) { i, stamp in
                stampOrb(stamp)
                    .position(orbPosition(for: i, total: stamps.count + 1))
                    .transition(orbTransition(index: i, total: stamps.count + 1))
            }
            moreOrb
                .position(orbPosition(for: stamps.count, total: stamps.count + 1))
                .transition(orbTransition(index: stamps.count, total: stamps.count + 1))

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

    // MARK: - 入/出场动效（"letters tumbling out of mailbox"）
    //
    // **入场**（fan-out 展开）：
    //   - 起点：从 icon 中心冒出 → scale 0.25 + opacity 0 + ±6° 旋转（错位翻滚）
    //   - 终点：orbPosition + scale 1 + opacity 1 + 0° rotation
    //   - 曲线：spring(0.45, 0.72) —— 微弹邀请感，不过冲
    //   - Stagger：每 orb +0.04s，按 12 点钟顺时针铺开
    //
    // **出场**（fan-out 收起）：
    //   - 起点：当前位置 → 终点 scale 0.4 + opacity 0（保留视觉余像，不归零）
    //   - 曲线：easeIn(0.18s) —— 干脆收尾，无 bounce（用户已决定，让路）
    //   - 反向 stagger：(total-1-i) × 0.025s，"信件次第回邮筒"
    //   - 总时长 ~0.2s + 8 × 0.025 ≈ 0.4s 末端 orb 完全收完
    //
    // Asymmetric in/out 符合 Apple HIG + Material Design 共识："退场快于入场"。

    private func orbTransition(index i: Int, total: Int) -> AnyTransition {
        let entryStagger = Double(i) * 0.04
        let exitStagger = Double(max(0, total - 1 - i)) * 0.025
        // 翻滚方向交替：偶数 -6°、奇数 +6°——视觉随机感不机械
        let tumbleRotation: Double = (i % 2 == 0) ? -6 : 6

        return .asymmetric(
            insertion: .modifier(
                active: OrbAppearModifier(scale: 0.25, opacity: 0, rotation: tumbleRotation),
                identity: OrbAppearModifier(scale: 1, opacity: 1, rotation: 0)
            )
            .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(entryStagger)),
            removal: .modifier(
                active: OrbAppearModifier(scale: 0.4, opacity: 0, rotation: 0),
                identity: OrbAppearModifier(scale: 1, opacity: 1, rotation: 0)
            )
            .animation(.easeIn(duration: 0.18).delay(exitStagger))
        )
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
// 三个变换合并（scale + opacity + rotation）放在一个 modifier 里——SwiftUI
// AnyTransition 不能直接组合 rotation，只能借 `.modifier(active:identity:)`
// 自定义。Active = "未出现" 状态；Identity = "已出现" 状态。

private struct OrbAppearModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    let rotation: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .center)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
    }
}
