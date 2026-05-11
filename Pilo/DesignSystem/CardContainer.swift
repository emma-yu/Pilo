import SwiftUI

/// 统一卡片视觉：圆角 PaperCard 底 + 柔和阴影 + 可选 severity 强调条。
/// 用于：RepoDetailView 各分区、PushConfirmDialog header、Onboarding hero 等。
struct PiloCardModifier: ViewModifier {
    let accent: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.paperCard)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    if let accent {
                        // 左侧 3px 强调条
                        Rectangle()
                            .fill(accent)
                            .frame(width: 3)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
            )
    }
}

extension View {
    func piloCard(
        accent: Color? = nil,
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 14
    ) -> some View {
        modifier(PiloCardModifier(accent: accent, cornerRadius: cornerRadius, padding: padding))
    }
}
