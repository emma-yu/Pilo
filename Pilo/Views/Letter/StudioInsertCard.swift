import SwiftUI

/// 收件箱列表底部「邮局便条」装饰卡——夹在所有信件之后，像信封里塞的小广告纸。
///
/// 视觉创新点：
///   1. **VerticalPerforation** —— 左侧一列空心金色小圆，邮票齿孔装饰边
///   2. **PostalDatestamp** —— 右上角圆形日戳（今日 MM.dd），双层圈 + 「POST」字样
///   3. **微旋 -1.2°** —— 像被人随手塞进信箱里的便条，尊重 reduceMotion 自动归零
///
/// 只在收件箱**非空**时出现；空状态保持冥想式无干扰。
struct StudioInsertCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var lang: Language { appState.language }

    var body: some View {
        HStack(spacing: 0) {
            VerticalPerforation(height: 104)
                .padding(.vertical, 6)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(lang == .zh ? "邮局便条 · A NOTE" : "A NOTE FROM THE STUDIO")
                    .font(.piloSerifLabel)
                    .foregroundStyle(Color.piloGoldDark)
                    .tracking(1.5)

                Text(Copy.Studio.studioName(lang))
                    .font(.custom("Songti SC", size: 13).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)

                Text(Copy.Studio.uvpeekOneLiner(lang))
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(StudioBranding.studioURL)
                    } label: {
                        HStack(spacing: 4) {
                            Text(Copy.Studio.visitSite(lang))
                                .font(.piloCaption)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .medium))
                        }
                    }
                    .buttonStyle(.piloSecondary)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.piloPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            PostalDatestamp(date: Date())
                .padding(.trailing, 10)
                .padding(.top, 8)
        }
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : -1.2))
    }
}

// MARK: - 私有装饰原语

/// 左侧竖向一列空心金色小圆，邮票齿孔感装饰边。
/// 不是真的"撕下来"的孔（背景色相同没法做出穿透效果），是装饰性齿孔标记。
private struct VerticalPerforation: View {
    var height: CGFloat = 96
    var dotCount: Int = 12
    var dotSize: CGFloat = 4

    var body: some View {
        Canvas { ctx, size in
            let radius = dotSize / 2
            let usableH = max(0, size.height - dotSize)
            let spacing = usableH / CGFloat(max(1, dotCount - 1))
            let x = size.width / 2
            for i in 0..<dotCount {
                let cy = radius + CGFloat(i) * spacing
                let rect = CGRect(
                    x: x - radius, y: cy - radius,
                    width: dotSize, height: dotSize
                )
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.piloGoldDark.opacity(0.4)),
                    lineWidth: 0.65
                )
            }
        }
        .frame(width: dotSize + 2, height: height)
        .accessibilityHidden(true)
    }
}

#Preview("Studio Insert Card") {
    VStack(spacing: 16) {
        StudioInsertCard()
    }
    .padding(32)
    .background(Color.piloPaper.opacity(0.95))
    .frame(width: 520)
}
