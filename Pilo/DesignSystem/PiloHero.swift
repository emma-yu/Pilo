import SwiftUI

/// 统一的 hero 区域：mascot + 大字 + 副标题 + 可选 sparkle 装饰。
/// 用于：onboarding screens、push 成功页、主窗口空态、settings 关于 tab。
struct PiloHero: View {

    let mood: PiloMascot.Mood
    var title: String
    var subtitle: String? = nil
    var mascotSize: CGFloat = 96
    var decorations: Bool = false

    var body: some View {
        VStack(spacing: PiloSpacing.l) {
            ZStack {
                if decorations {
                    SparkleCluster(mascotSize: mascotSize)
                }
                PiloMascot(mood: mood, size: mascotSize, breathing: true)
            }
            VStack(spacing: PiloSpacing.s) {
                Text(title)
                    .font(.piloHero)
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.piloBody)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, PiloSpacing.xl)
        }
        .padding(.vertical, PiloSpacing.l)
    }
}

/// 围绕 mascot 的 2-3 个静态 sparkle 点。**完全不动**——静态装饰，不算 motion。
/// 半径按 mascotSize 放大；偏移用伪随机但稳定的位置（不会每次重渲变形）。
struct SparkleCluster: View {
    let mascotSize: CGFloat

    var body: some View {
        ZStack {
            // 三个 sparkle，位置围绕 mascot 中心
            sparkle(offsetX: -mascotSize * 0.55, offsetY: -mascotSize * 0.45, size: 8, color: .piloAccent)
            sparkle(offsetX: mascotSize * 0.6,   offsetY: -mascotSize * 0.2, size: 6, color: .piloBlueLight)
            sparkle(offsetX: -mascotSize * 0.3,  offsetY: mascotSize * 0.5,  size: 5, color: .piloAccent)
        }
        .frame(width: mascotSize, height: mascotSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sparkle(offsetX: CGFloat, offsetY: CGFloat, size: CGFloat, color: Color) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color.opacity(0.7))
            .symbolRenderingMode(.hierarchical)
            .offset(x: offsetX, y: offsetY)
    }
}

#Preview {
    PiloHero(
        mood: .happy,
        title: "找到了 12 个仓库",
        subtitle: "去看看吧～",
        decorations: true
    )
    .frame(width: 480, height: 360)
    .background(Color.creamBg)
}
