import SwiftUI

/// 四种 reusable Button style，统一品牌手感 + 微交互。
/// 都遵守 Reduce Motion：开启时 press 反馈改为 opacity 而非 scale。
enum PiloButtonRole {
    case primary       // 主 CTA（推送 / 继续）：PiloBlue 填充
    case secondary     // 次操作（取消 / 跳过）：bordered，hover 时 PiloBlueLight bg
    case ghost         // 卡片内 inline chip：透明，hover 时显形
    case destructive   // bypass：roseDanger 填充
}

struct PiloButtonStyle: ButtonStyle {
    let role: PiloButtonRole
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(background(for: configuration))
            .foregroundStyle(foreground(for: configuration))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(borderOverlay(for: configuration))
            .scaleEffect(scale(for: configuration))
            .opacity(opacity(for: configuration))
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }

    // MARK: - 度量

    private var horizontalPadding: CGFloat {
        switch role {
        case .ghost:        return 8
        default:            return 16
        }
    }
    private var verticalPadding: CGFloat {
        switch role {
        case .ghost:        return 4
        default:            return 8
        }
    }
    private var minHeight: CGFloat {
        switch role {
        case .ghost:        return 24
        default:            return 32
        }
    }
    private var cornerRadius: CGFloat {
        switch role {
        case .ghost:        return 6
        default:            return 8
        }
    }

    // MARK: - 颜色

    @ViewBuilder
    private func background(for cfg: Configuration) -> some View {
        switch role {
        case .primary:
            (cfg.isPressed ? Color.piloBlueDark : Color.piloBlue)
                .opacity(isEnabled ? 1.0 : 0.5)
        case .secondary:
            Color.piloBlueLight.opacity(cfg.isPressed ? 0.35 : 0.0)
        case .ghost:
            Color.cloudDivider.opacity(cfg.isPressed ? 0.7 : 0.5)
        case .destructive:
            (cfg.isPressed ? Color.piloBlueDark : Color.roseDanger)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
    }

    private func foreground(for cfg: Configuration) -> Color {
        switch role {
        case .primary, .destructive:
            return .white
        case .secondary, .ghost:
            return isEnabled ? .inkPrimary : .inkTertiary
        }
    }

    @ViewBuilder
    private func borderOverlay(for cfg: Configuration) -> some View {
        if role == .secondary {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.piloBlue.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - 动效

    private func scale(for cfg: Configuration) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        return cfg.isPressed ? 0.97 : 1.0
    }

    private func opacity(for cfg: Configuration) -> Double {
        guard reduceMotion else { return 1.0 }
        return cfg.isPressed ? 0.7 : 1.0
    }
}

extension ButtonStyle where Self == PiloButtonStyle {
    static var piloPrimary: PiloButtonStyle     { PiloButtonStyle(role: .primary) }
    static var piloSecondary: PiloButtonStyle   { PiloButtonStyle(role: .secondary) }
    static var piloGhost: PiloButtonStyle       { PiloButtonStyle(role: .ghost) }
    static var piloDestructive: PiloButtonStyle { PiloButtonStyle(role: .destructive) }
}
