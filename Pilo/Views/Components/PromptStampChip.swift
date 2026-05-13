import SwiftUI

/// 单张「Prompt 邮票」视觉组件 —— sidebar / archive 都用。
///
/// 默认样式：圆形 24pt + emoji 居中 + tint bg + 金色描边 + -3° 倾斜（"盖章瞬间"质感）。
///
/// 提供两个 size 变体：
///   - `.compact`（默认 24pt）—— sidebar 用
///   - `.large`（36pt）—— archive sheet 用
///
/// 点击 / 右键 / hover 行为由父 view 提供；本组件**仅渲染**邮票本身。
struct PromptStampChip: View {
    let stamp: PromptStamp
    var size: Size = .compact
    var rotated: Bool = true       // 是否带 -3° 倾斜（archive sheet row 可关掉避免视觉碎）

    enum Size {
        case compact   // 24pt 圆 —— sidebar
        case large     // 36pt 圆 —— archive

        var diameter: CGFloat {
            switch self {
            case .compact: return 24
            case .large:   return 36
            }
        }
        var emojiFontSize: CGFloat {
            switch self {
            case .compact: return 13
            case .large:   return 20
            }
        }
    }

    var body: some View {
        Text(stamp.emoji.isEmpty ? "✨" : stamp.emoji)
            .font(.system(size: size.emojiFontSize))
            .frame(width: size.diameter, height: size.diameter)
            .background(
                Circle().fill(stamp.tint.color.opacity(0.18))
            )
            .overlay(
                Circle()
                    .stroke(Color.piloGold.opacity(0.55), lineWidth: 0.5)
            )
            .rotationEffect(.degrees(rotated ? -3 : 0))
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ForEach(PromptStamp.StampTint.allCases, id: \.self) { tint in
                PromptStampChip(
                    stamp: PromptStamp(title: "重构", body: "...", emoji: "🔧", tint: tint),
                    size: .compact
                )
            }
        }
        HStack(spacing: 16) {
            PromptStampChip(stamp: .init(title: "解释", body: "...", emoji: "📖", tint: .gold), size: .large)
            PromptStampChip(stamp: .init(title: "Bug", body: "...", emoji: "🐛", tint: .rose), size: .large)
            PromptStampChip(stamp: .init(title: "测试", body: "...", emoji: "✨", tint: .mint), size: .large)
        }
    }
    .padding(40)
    .background(Color.creamBg)
}
