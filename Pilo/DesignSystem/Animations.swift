import SwiftUI

extension Animation {
    static let piloSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// 用于 Pilo mascot 的"呼吸"——2.5 秒 cycle，平缓 easeInOut，无限循环。
    /// 调用方应只在 reduceMotion 为 false 时启用。
    static let piloBreathing = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)

    /// 按钮 press 反馈短促 spring，比 piloSpring 更快、更弹。
    static let piloPress = Animation.spring(response: 0.18, dampingFraction: 0.7)

    /// hover 状态变化用，比 motion 更克制——只是颜色淡入淡出。
    static let piloHover = Animation.easeInOut(duration: 0.12)

    static func piloRespectMotion(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .piloSpring
    }
}
