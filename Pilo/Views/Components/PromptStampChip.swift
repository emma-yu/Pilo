import SwiftUI

/// 单张「Prompt 邮票」视觉组件 —— sidebar / archive 都用。
///
/// **两种渲染模式：**
///   - `stamp.design != nil` —— 完整 postage 邮票 illustration（PNG asset，矩形带 perforation）
///   - `stamp.design == nil` —— 老 fallback：emoji 居中圆盘（向后兼容旧数据）
///
/// 都带 -3° 倾斜（"盖章瞬间"质感）。
struct PromptStampChip: View {
    let stamp: PromptStamp
    var size: Size = .compact
    var rotated: Bool = true

    enum Size {
        case compact   // sidebar 紧凑
        case grid      // sidebar grid 主 cell
        case large     // archive sheet / editor preview

        /// 邮票宽度（矩形 illustration 模式）
        var width: CGFloat {
            switch self {
            case .compact: return 36
            case .grid:    return 52
            case .large:   return 64
            }
        }
        /// 邮票高度 —— illustration 是横长方形（≈1:0.9）
        var height: CGFloat {
            width * 0.92
        }
        /// 旧 fallback 圆盘直径
        var fallbackDiameter: CGFloat {
            switch self {
            case .compact: return 24
            case .grid:    return 40
            case .large:   return 48
            }
        }
        var fallbackEmojiSize: CGFloat {
            switch self {
            case .compact: return 13
            case .grid:    return 20
            case .large:   return 24
            }
        }
    }

    var body: some View {
        Group {
            if let design = stamp.design {
                Image(design.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            } else {
                // 旧数据 fallback：emoji + 圆盘 tint
                Text(stamp.emoji.isEmpty ? "✨" : stamp.emoji)
                    .font(.system(size: size.fallbackEmojiSize))
                    .frame(width: size.fallbackDiameter, height: size.fallbackDiameter)
                    .background(Circle().fill(stamp.tint.color.opacity(0.18)))
                    .overlay(
                        Circle()
                            .stroke(Color.piloGold.opacity(0.55), lineWidth: 0.5)
                    )
            }
        }
        .rotationEffect(.degrees(rotated ? -3 : 0))
    }
}

#Preview {
    VStack(spacing: 20) {
        // illustration 模式
        HStack(spacing: 10) {
            ForEach(StampDesign.allCases, id: \.self) { d in
                PromptStampChip(
                    stamp: PromptStamp(title: d.labelZH, body: "...", design: d),
                    size: .grid
                )
            }
        }
        // 旧 fallback 模式
        HStack(spacing: 12) {
            PromptStampChip(
                stamp: PromptStamp(title: "重构", body: "...", emoji: "🔧"),
                size: .compact
            )
            PromptStampChip(
                stamp: PromptStamp(title: "Bug", body: "...", emoji: "🐛", tint: .rose),
                size: .grid
            )
        }
    }
    .padding(40)
    .background(Color.creamBg)
}
