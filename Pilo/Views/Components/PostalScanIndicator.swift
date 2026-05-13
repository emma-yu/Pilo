import SwiftUI

/// **PostalWaveDots** —— 3 个金色 dot 跑波浪的纯动画原语。
///
/// 替代 macOS 系统的 ProgressView 系统菊花。设计语言：
///   - 3 个 piloGoldDark dot，可调 size（默认 5pt）
///   - 间距 5pt
///   - 每个 dot 的 opacity / scale 用 sin wave 驱动，相位 stagger 0.25s 让"波"
///     从左流到右循环 —— 像信件被一封封翻看
///   - 周期 0.9s —— alive but not anxious
///   - Reduce Motion: 冻结到 0.7 opacity 静态 dot
///
/// 任何"正在做事"的语境都可以用：sidebar 扫盘、push 准备、letter compose 等
struct PostalWaveDots: View {
    var size: CGFloat = 5
    var spacing: CGFloat = 5
    var tint: Color = .piloGoldDark

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(tint.opacity(0.7))
                        .frame(width: size, height: size)
                }
            }
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: spacing) {
                    ForEach(0..<3, id: \.self) { i in
                        // 周期 0.9s，stagger 0.25s（波跨越 3 dots ~0.5s）
                        let phase = (t - Double(i) * 0.25) * 2 * .pi / 0.9
                        let wave = (sin(phase) + 1) / 2   // 0..1
                        Circle()
                            .fill(tint)
                            .frame(width: size, height: size)
                            .opacity(0.3 + wave * 0.7)
                            .scaleEffect(0.85 + wave * 0.3)
                    }
                }
            }
            // 固定外框防 wave 时 layout 抖
            .frame(width: size * 3 + spacing * 2 + 4, height: size + 2)
        }
    }
}

/// **PostalScanIndicator** —— "巡视中"胶囊（dots + 文案 + cream paper bg）
///
/// 两个尺寸变体：
///   - `.sidebar` —— 大号，曾在 sidebar 底部用（v1）
///   - `.topbar`  —— 紧凑款，跟 inbox / health pill 同高 (~22pt)，在 PanelHeader 右侧
///
/// 用法：`if appState.isScanning { PostalScanIndicator(...) }`
struct PostalScanIndicator: View {

    let tone: Tone
    let lang: Language
    var size: Size = .sidebar

    enum Size {
        case sidebar
        case topbar
    }

    var body: some View {
        HStack(spacing: size == .topbar ? 6 : 8) {
            PostalWaveDots(size: size == .topbar ? 4 : 5)
            Text(Copy.Scanning.sidebarHint(tone, lang))
                .font(size == .topbar
                      ? .piloSerifCaption
                      : .piloSerifCaption)
                .italic()
                .foregroundStyle(Color.piloGoldDark.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, size == .topbar ? 10 : 14)
        .padding(.vertical, size == .topbar ? 4 : 10)
        .background(
            // topbar 用跟其它 pill 一致的 RoundedRectangle 7pt；sidebar 用 capsule
            Group {
                if size == .topbar {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.piloGold.opacity(0.15))
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.piloPaper.opacity(0.7))
                }
            }
        )
        .overlay(
            Group {
                if size == .sidebar {
                    Capsule(style: .continuous)
                        .stroke(Color.piloGold.opacity(0.3), lineWidth: 0.5)
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Scanning.sidebarHint(tone, lang))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(spacing: 24) {
        PostalWaveDots()
        PostalWaveDots(size: 7)
        PostalScanIndicator(tone: .friendly, lang: .zh)
        PostalScanIndicator(tone: .minimal, lang: .zh)
        PostalScanIndicator(tone: .friendly, lang: .en)
    }
    .padding(40)
    .background(Color.creamBg)
}
