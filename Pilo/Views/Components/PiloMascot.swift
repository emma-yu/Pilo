import SwiftUI

/// Pilo 真实信鸽 mascot。v3.1：用 `PiloMascotFull` 真实 PNG 替代之前的 SF Symbol 占位。
/// Mood 通过细微 overlay 区分（happy 撒 sparkle、sleeping 加 ZZZ、worried 降饱和 等），
/// 一张底图 + 装饰，避免做 7 张 SVG。
struct PiloMascot: View {

    enum Mood: String, CaseIterable, Sendable {
        case sleeping, alert, worried, happy, raining, flying, sunglasses
    }

    let mood: Mood
    var size: CGFloat = 64
    var breathing: Bool = false

    @Environment(\.tone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var breathPhase: Bool = false

    /// 呼吸仅在三者同时成立时进行：调用方要求 + 未开 reduce-motion + 窗口当前活跃。
    /// 切到别的 App / 窗口进入后台 → controlActiveState == .inactive → 暂停，避免
    /// repeatForever 把 SwiftUI 渲染循环钉在满刷新率空转烧 CPU（仅前台可见时才呼吸）。
    private var shouldBreathe: Bool {
        breathing && !reduceMotion && controlActiveState != .inactive
    }

    var body: some View {
        ZStack {
            // 底图：真实鸽子叼信封
            Image("PiloMascotFull")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .saturation(mood == .worried ? 0.65 : 1.0)
                .rotationEffect(.degrees(mood == .flying ? -6 : 0))

            // Mood-specific 装饰
            moodOverlay
                .frame(width: size, height: size)
        }
        .scaleEffect(currentScale)
        .shadow(color: .black.opacity(0.10), radius: size * 0.06, y: size * 0.04)
        // 单个 .task(id:)：appear 时按初始 shouldBreathe 起停，之后每次翻转自动重跑。
        // 一条代码路径，无双触发/漏触发/首帧闪。窗口失活 → 收敛到静止 → 渲染循环 idle。
        .task(id: shouldBreathe) {
            if shouldBreathe {
                withAnimation(.piloBreathing) { breathPhase = true }
            } else {
                // 有限动画把 breathPhase 收敛回 false(scale→1.0)，替换正在跑的
                // repeatForever transaction；0.25s 后无动画在跑 → display link idle。
                withAnimation(.easeOut(duration: 0.25)) { breathPhase = false }
            }
        }
        .accessibilityLabel(Copy.MascotA11y.label(for: mood, tone: tone))
    }

    @ViewBuilder
    private var moodOverlay: some View {
        switch mood {
        case .happy:
            // 3 个 sparkle 围绕头部，PiloAccent 心粉色
            ZStack {
                sparkle(at: CGPoint(x: 0.12, y: 0.12), size: size * 0.10)
                sparkle(at: CGPoint(x: 0.85, y: 0.22), size: size * 0.08)
                sparkle(at: CGPoint(x: 0.25, y: 0.78), size: size * 0.06)
            }
        case .sleeping:
            // ZZZ 在右上
            Text("z")
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.piloBlueLight)
                .position(x: size * 0.85, y: size * 0.20)
                .rotationEffect(.degrees(-10))
                .opacity(0.7)
        case .raining:
            // 小雨滴
            Text("☔︎")
                .font(.system(size: size * 0.32))
                .position(x: size * 0.85, y: size * 0.25)
        case .sunglasses:
            // 小墨镜 emoji-style overlay（位置 + 大小都靠经验值，鸽子头大约在上 1/3）
            Capsule()
                .fill(Color.inkPrimary.opacity(0.85))
                .frame(width: size * 0.30, height: size * 0.08)
                .position(x: size * 0.50, y: size * 0.32)
        case .alert, .worried, .flying:
            EmptyView()
        }
    }

    private func sparkle(at relativePosition: CGPoint, size sparkleSize: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: sparkleSize, weight: .semibold))
            .foregroundStyle(Color.piloAccent.opacity(0.8))
            .symbolRenderingMode(.hierarchical)
            .position(x: size * relativePosition.x, y: size * relativePosition.y)
    }

    private var currentScale: CGFloat {
        guard breathing, !reduceMotion else { return 1.0 }
        return breathPhase ? 1.03 : 1.0
    }
}

#Preview("All moods") {
    VStack(spacing: 24) {
        HStack(spacing: 28) {
            ForEach([PiloMascot.Mood.sleeping, .alert, .worried, .happy].self, id: \.self) { m in
                VStack {
                    PiloMascot(mood: m, size: 80)
                    Text(m.rawValue).font(.caption)
                }
            }
        }
        HStack(spacing: 28) {
            ForEach([PiloMascot.Mood.raining, .flying, .sunglasses].self, id: \.self) { m in
                VStack {
                    PiloMascot(mood: m, size: 80)
                    Text(m.rawValue).font(.caption)
                }
            }
        }
    }
    .padding(28)
    .background(Color.creamBg)
}
