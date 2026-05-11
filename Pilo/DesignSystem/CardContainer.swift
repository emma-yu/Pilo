import SwiftUI

/// 统一卡片视觉：圆角 PaperCard 底 + 柔和（可多层）阴影 + 可选 severity 强调条。
/// 用于：RepoDetailView 各分区、PushConfirmDialog header、Onboarding hero 等。
struct PiloCardModifier: ViewModifier {
    let accent: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat
    let elevation: Elevation

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
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
            .elevation(elevation)
    }
}

extension View {
    func piloCard(
        accent: Color? = nil,
        cornerRadius: CGFloat = PiloRadius.card,
        padding: CGFloat = PiloSpacing.l,
        elevation: Elevation = .normal
    ) -> some View {
        modifier(PiloCardModifier(
            accent: accent,
            cornerRadius: cornerRadius,
            padding: padding,
            elevation: elevation
        ))
    }
}
