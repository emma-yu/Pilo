import SwiftUI

/// 给任意 view 加 macOS-native hover 反馈：
/// - 鼠标悬停时显示淡背景
/// - 鼠标 cursor → pointing hand
/// - 12ms 透明度过渡（不抢戏）
struct HoverableRowModifier: ViewModifier {
    let highlight: Color
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovered ? highlight : .clear)
                    .animation(.easeInOut(duration: 0.12), value: isHovered)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    /// 主要给 list row、menu action row、卡片用。
    /// 默认背景是 `piloBlue` 8% 透明度——足够提示"可点"但不喧宾夺主。
    func hoverable(
        highlight: Color = Color.piloBlue.opacity(0.08),
        cornerRadius: CGFloat = 8
    ) -> some View {
        modifier(HoverableRowModifier(highlight: highlight, cornerRadius: cornerRadius))
    }
}
