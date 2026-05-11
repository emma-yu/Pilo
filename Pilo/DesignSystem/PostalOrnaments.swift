import SwiftUI

// MARK: - Ornament Divider（横向装饰线：金星 + 虚线 + 圆点）

/// HTML 参考的顶部装饰线：左侧曲线 + 中央 5 角星 + 右侧曲线 + 散落小圆点。
/// 用 SwiftUI Path 描绘，所有颜色用 PiloGold + 状态色。
struct OrnamentDivider: View {
    var width: CGFloat = 240
    var height: CGFloat = 16

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let mid = h / 2

            // 左侧波浪曲线
            var leftCurve = Path()
            leftCurve.move(to: CGPoint(x: w * 0.04, y: mid))
            leftCurve.addQuadCurve(
                to: CGPoint(x: w * 0.27, y: mid),
                control: CGPoint(x: w * 0.15, y: mid - 5)
            )
            leftCurve.addQuadCurve(
                to: CGPoint(x: w * 0.44, y: mid),
                control: CGPoint(x: w * 0.36, y: mid + 5)
            )
            ctx.stroke(leftCurve, with: .color(Color.piloGold), lineWidth: 0.8)

            // 中央 5 角星
            let starCenter = CGPoint(x: w * 0.49, y: mid)
            var star = Path()
            star.move(to: CGPoint(x: starCenter.x, y: starCenter.y - 4))
            star.addLine(to: CGPoint(x: starCenter.x + 4, y: starCenter.y))
            star.addLine(to: CGPoint(x: starCenter.x, y: starCenter.y + 4))
            star.addLine(to: CGPoint(x: starCenter.x - 4, y: starCenter.y))
            star.closeSubpath()
            ctx.fill(star, with: .color(Color.piloGold))

            // 右侧波浪曲线
            var rightCurve = Path()
            rightCurve.move(to: CGPoint(x: w * 0.57, y: mid))
            rightCurve.addQuadCurve(
                to: CGPoint(x: w * 0.78, y: mid),
                control: CGPoint(x: w * 0.67, y: mid + 5)
            )
            rightCurve.addQuadCurve(
                to: CGPoint(x: w * 0.96, y: mid),
                control: CGPoint(x: w * 0.87, y: mid - 5)
            )
            ctx.stroke(rightCurve, with: .color(Color.piloGold), lineWidth: 0.8)

            // 散落小圆点（amber / mint / rose / amber）
            let dots: [(CGFloat, CGFloat, Color, CGFloat)] = [
                (w * 0.17, mid - 3,  .amberWarn,    0.9),
                (w * 0.83, mid + 3,  .amberWarn,    0.9),
                (w * 0.32, mid + 3,  .mintSafe,     0.7),
                (w * 0.66, mid - 3,  .roseDanger,   0.7),
            ]
            for (x, y, color, radius) in dots {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color)
                )
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Section Divider（斜体宋体标签 + 金色渐变线）

/// 章节分隔：「— 待寄出的小信 —」斜体宋体 + 右侧渐变金线
struct SectionDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: PiloSpacing.s) {
            Text(label)
                .font(.piloSerifLabel)
                .foregroundStyle(Color.piloGoldDark)
                .tracking(0.5)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.piloGold, Color.piloGold.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.vertical, PiloSpacing.xs)
    }
}

// MARK: - Rotated Stamp（旋转虚线邮票）

/// 旋转 -3°/6° 的虚线边邮票，用于"已沉睡 30 天"、"已寄出 · 2026.05.11" 等。
struct RotatedStamp: View {
    let text: String
    var tint: Color = .stampRed
    var rotation: Double = -3
    var dashStyle: Bool = true   // 虚线 or 实线

    var body: some View {
        Text(text)
            .font(.piloSerifCaption)
            .tracking(1.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        tint,
                        style: dashStyle
                            ? StrokeStyle(lineWidth: 1, dash: [3, 2])
                            : StrokeStyle(lineWidth: 1.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.paperCard.opacity(0.4))
                    )
            )
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }
}

// MARK: - Cream Card（信纸黄底 + 金色细边）

struct PiloCreamCardModifier: ViewModifier {
    var padding: CGFloat = PiloSpacing.m
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.piloPaper)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.piloPaperBorder, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    /// 信纸黄底卡片，用于 commit / stash / 仪式时刻的"信件"展示
    func piloCreamCard(padding: CGFloat = PiloSpacing.m, cornerRadius: CGFloat = 8) -> some View {
        modifier(PiloCreamCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

#Preview("Postal Ornaments") {
    VStack(spacing: 24) {
        OrnamentDivider(width: 240)
        SectionDivider(label: "— 待寄出的小信 —")
        HStack(spacing: 16) {
            RotatedStamp(text: "已沉睡 30 天", tint: .stampRed, rotation: 6)
            RotatedStamp(text: "已寄出 · 2026.05.11", tint: .stampMint, rotation: -3, dashStyle: false)
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("8a3f2c1").font(.piloMono).foregroundStyle(.orange)
                Text("feat: add hourly forecast cache").font(.system(size: 12))
                Spacer()
                Text("1h ago").font(.piloSerifCaption).foregroundStyle(.secondary)
            }
        }
        .piloCreamCard()
    }
    .padding(32)
    .background(Color.creamBg)
}
