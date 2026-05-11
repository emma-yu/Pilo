import SwiftUI

/// 统一的 pill-shaped chip 组件。
/// 替代以前的 StatusBadge 与各种 inline 染色 Text。
struct PiloChip: View {

    enum Style {
        case filled    // 彩色背景 + 白字
        case tinted    // 半透明 tint 背景 + tint 文字
        case outline   // 透明 + tint 描边
    }

    enum Size {
        case small     // height 18
        case medium    // height 22
        case large     // height 28
    }

    var icon: String? = nil
    var text: String
    var tint: Color = .piloBlue
    var style: Style = .tinted
    var size: Size = .small

    var body: some View {
        HStack(spacing: spacing) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            Text(text)
                .font(textFont)
                .fontWeight(.medium)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(minHeight: height)
        .background(backgroundShape)
    }

    // MARK: - 度量

    private var height: CGFloat {
        switch size {
        case .small:  return 18
        case .medium: return 22
        case .large:  return 28
        }
    }
    private var horizontalPadding: CGFloat {
        switch size {
        case .small:  return 8
        case .medium: return 10
        case .large:  return 12
        }
    }
    private var verticalPadding: CGFloat {
        switch size {
        case .small:  return 2
        case .medium: return 3
        case .large:  return 4
        }
    }
    private var spacing: CGFloat {
        switch size {
        case .small:  return 4
        case .medium: return 5
        case .large:  return 6
        }
    }
    private var iconSize: CGFloat {
        switch size {
        case .small:  return 10
        case .medium: return 11
        case .large:  return 13
        }
    }
    private var textFont: Font {
        switch size {
        case .small:  return .system(size: 11, weight: .medium)
        case .medium: return .system(size: 12, weight: .medium)
        case .large:  return .system(size: 13, weight: .medium)
        }
    }

    // MARK: - 颜色

    private var foreground: Color {
        switch style {
        case .filled:  return .white
        case .tinted:  return tint
        case .outline: return tint
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        let shape = Capsule(style: .continuous)
        switch style {
        case .filled:
            shape.fill(tint)
        case .tinted:
            shape.fill(tint.opacity(0.16))
        case .outline:
            shape.stroke(tint, lineWidth: 1)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
            PiloChip(icon: "arrow.up", text: "2", tint: .amberWarn)
            PiloChip(icon: "arrow.down", text: "1", tint: .lavenderInfo)
            PiloChip(icon: "pencil", text: "5 待提交", tint: .roseDanger)
            PiloChip(icon: "checkmark", text: "已同步", tint: .mintSafe)
        }
        HStack {
            PiloChip(icon: "shippingbox.fill", text: "12 仓库 · 3 待推送", tint: .piloBlue, style: .tinted, size: .medium)
        }
        HStack {
            PiloChip(text: "Filled", tint: .piloBlue, style: .filled, size: .large)
            PiloChip(text: "Outline", tint: .piloBlue, style: .outline, size: .large)
        }
    }
    .padding()
    .background(Color.creamBg)
}
