import SwiftUI

// MARK: - Wax Seal（蜡封）
/// 圆形红蜡封带星纹，用于"已寄出"／"已完成"等仪式时刻。
struct WaxSeal: View {
    var size: CGFloat = 56
    var label: String? = nil

    var body: some View {
        ZStack {
            // 蜡封主体——多层红色叠加，有立体感
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.piloAccent, Color(red: 0.78, green: 0.30, blue: 0.30)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .overlay(
                    // 锯齿状外环（蜡溅出的形状用 dashed stroke 近似）
                    Circle()
                        .stroke(Color(red: 0.65, green: 0.22, blue: 0.22),
                                style: StrokeStyle(lineWidth: 1.5, dash: [2, 1.5]))
                        .blur(radius: 0.3)
                )
                .shadow(color: .black.opacity(0.15), radius: size * 0.05, y: size * 0.03)

            // 中央花纹——五角星形 / 邮务徽
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(Color(red: 0.55, green: 0.15, blue: 0.15).opacity(0.75))

            // 可选 label（如 "SENT"），蜡封下方
            if let label {
                Text(label)
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
                    .offset(y: size * 0.25)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))   // 略斜，手贴感
        .accessibilityHidden(true)
    }
}

// MARK: - Envelope Corner（信封折角）
/// 卡片右上角的"信封折叠"装饰：内层颜色三角 + 外层折痕线
struct EnvelopeCorner: View {
    var size: CGFloat = 28
    var fillColor: Color = .piloCream
    var foldColor: Color = .piloBlueLight

    var body: some View {
        ZStack {
            // 折角后面露出的"信纸"颜色
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size, y: 0))
                p.addLine(to: CGPoint(x: size, y: size))
                p.closeSubpath()
            }
            .fill(fillColor)

            // 折痕线
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size, y: size))
            }
            .stroke(foldColor, lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Postage Stamp（邮票边）
/// 带锯齿边的小色块，像一枚邮票。用于挂在卡片角上做装饰章。
struct PostageStamp<Content: View>: View {
    var tint: Color = .piloBlue
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.opacity(0.10))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(tint, style: StrokeStyle(lineWidth: 1, dash: [2, 1.5]))
                }
            )
            .rotationEffect(.degrees(-3))
            .accessibilityHidden(true)
    }
}

// MARK: - Hand-drawn underline（手绘下划线）
/// 略带波动的下划线，给小标签增加"手写笔记"感
struct HandDrawnUnderline: View {
    var width: CGFloat = 80
    var color: Color = .piloAccent

    var body: some View {
        Path { p in
            // 略不规则的弧线
            p.move(to: CGPoint(x: 0, y: 2))
            p.addCurve(
                to: CGPoint(x: width, y: 1.5),
                control1: CGPoint(x: width * 0.3, y: -0.5),
                control2: CGPoint(x: width * 0.7, y: 3.5)
            )
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .frame(width: width, height: 4)
        .accessibilityHidden(true)
    }
}

#Preview("Decorations") {
    VStack(spacing: 32) {
        WaxSeal(size: 64, label: "SENT")
        EnvelopeCorner(size: 36)
        PostageStamp(tint: .mintSafe) {
            Text("PRIVATE").font(.system(size: 9, weight: .bold)).tracking(1)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text("章节标题").font(.piloSection)
            HandDrawnUnderline(width: 60)
        }
    }
    .padding(32)
    .background(Color.creamBg)
}
