import SwiftUI

/// 关于页底部 fine-print 三行——故意克制版（重设计于 2026-05-14）。
///
/// 原始版本（cream 卡 + PostalRail + 琥珀 SisterMark + 两层 section label）被用户
/// 反馈"招摇"。问题根因：视觉权重错位——本应是关于页第 4 级 fine-print
/// （和 "Made with 🕊️ by Emma" 同级），却用了 mascot 仪式级的色彩 / 装饰。
///
/// 此次重设计：
///   - **去掉**：cream 卡 + 描边、PostalRail 圆戳、SisterMark 琥珀 sun 章、
///             "邮政集团 · 营运" / "同门作品" 两个 section label、studio tagline
///   - **保留**：三行 Songti 文本 + 极薄金线分隔
///   - **新增**：URL 直接写在按钮文案里（"访问 xinxinmingde.com"）—— 最透明
///
/// 视觉创新点：**克制本身就是这个 surface 的创新答案**。
/// 关于页是 Pilo 自己的主场，工作室署名必须比 mascot / hero / git info 都低。
struct AboutStudioBlock: View {

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 6) {
            // 极薄金色渐变线 —— 比 OrnamentDivider 安静一档，仅作 section 边界提示
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.piloGold.opacity(0),
                            Color.piloGold.opacity(0.4),
                            Color.piloGold.opacity(0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 100, height: 0.6)
                .padding(.bottom, 4)

            Text(Copy.Studio.aboutMadeBy(lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)

            Text(Copy.Studio.aboutSisterLine(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkTertiary)

            Button {
                NSWorkspace.shared.open(StudioBranding.studioURL)
            } label: {
                HStack(spacing: 3) {
                    Text(Copy.Studio.aboutVisitLink(lang))
                        .font(.piloSerifCaption)
                        .italic()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundStyle(Color.piloGoldDark.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("About Studio Block · calm") {
    AboutStudioBlock()
        .frame(width: 540)
        .padding(24)
        .background(Color.piloCream.opacity(0.5))
}
