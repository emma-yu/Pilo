import SwiftUI

/// Sidebar 底部"Pilo 正在巡视"的呼吸 indicator。
///
/// 替代 macOS 系统的 ProgressView spinner —— 系统级菊花跟邮局美学完全不搭。
/// 设计语言：
///   - 3 个 piloGoldDark dot，4pt 直径，间距 5pt
///   - 每个 dot 的 opacity / scale 用 sin wave 驱动，相位 stagger 0.4 让"波"
///     从左流到右，再循环 —— 像信件被一封封翻看
///   - 旁边 Songti italic caption "巡视小邮局..."，跟整个 sidebar 衬线语调对齐
///   - Reduce Motion: 动画停在中位（dots 1.0 / 0.55 / 1.0 静态），caption 仍显示
///
/// 用法：`if appState.isScanning { PostalScanIndicator(...) }` 挂在 sidebar 底部
struct PostalScanIndicator: View {

    let tone: Tone
    let lang: Language

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            wavingDots
            Text(Copy.Scanning.sidebarHint(tone, lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.piloGoldDark.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            // 极淡 cream paper 圆角胶囊，让 indicator 跟 sidebar bg 微微分层
            Capsule(style: .continuous)
                .fill(Color.piloPaper.opacity(0.7))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.piloGold.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Scanning.sidebarHint(tone, lang))
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var wavingDots: some View {
        if reduceMotion {
            // 静态版：避免给 motion-sensitive 用户造成不适
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.piloGoldDark.opacity(0.7))
                        .frame(width: 5, height: 5)
                }
            }
        } else {
            // TimelineView 提供高频 redraw 驱动 sine wave，无需 withAnimation 链
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        // 周期 ~0.9s，stagger 0.25s（dots 跨 0.5s 完成一波）
                        let phase = (t - Double(i) * 0.25) * 2 * .pi / 0.9
                        let wave = (sin(phase) + 1) / 2   // 0..1
                        Circle()
                            .fill(Color.piloGoldDark)
                            .frame(width: 5, height: 5)
                            .opacity(0.3 + wave * 0.7)
                            .scaleEffect(0.85 + wave * 0.3)
                    }
                }
            }
            .frame(width: 25, height: 8)   // 固定大小防 wave 时 layout 抖
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PostalScanIndicator(tone: .friendly, lang: .zh)
        PostalScanIndicator(tone: .minimal, lang: .zh)
        PostalScanIndicator(tone: .friendly, lang: .en)
    }
    .padding(40)
    .background(Color.creamBg)
}
