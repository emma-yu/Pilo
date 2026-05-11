import SwiftUI

/// 统一卡片视觉：圆角 PaperCard 底 + 默认 hairline 边界（Bear-vibe）或可选阴影。
/// 用于：RepoDetailView 各分区、PushConfirmDialog header、Onboarding hero 等。
///
/// Bear-vibe 默认：**无阴影，仅 1px hairline 边界**。需要"浮起"感的地方显式传 `elevation: .subtle/.normal/.elevated`。
struct PiloCardModifier: ViewModifier {
    let accent: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat
    let elevation: Elevation?
    let useHairline: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    shape.fill(Color.paperCard)
                    if let accent {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 3)
                            .clipShape(shape)
                    }
                }
            )
            .overlay(
                useHairline
                    ? shape.stroke(Color.cloudDivider.opacity(0.5), lineWidth: 1)
                    : nil
            )

        if let elevation {
            return AnyView(base.elevation(elevation))
        } else {
            return AnyView(base)
        }
    }
}

extension View {
    /// 默认 Bear-vibe：hairline border 无阴影。要"浮起"显式传 elevation。
    func piloCard(
        accent: Color? = nil,
        cornerRadius: CGFloat = PiloRadius.card,
        padding: CGFloat = PiloSpacing.xl,
        elevation: Elevation? = nil
    ) -> some View {
        modifier(PiloCardModifier(
            accent: accent,
            cornerRadius: cornerRadius,
            padding: padding,
            elevation: elevation,
            useHairline: elevation == nil
        ))
    }
}
