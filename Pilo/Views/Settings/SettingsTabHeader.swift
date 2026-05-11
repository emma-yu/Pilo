import SwiftUI

/// 邮局风 Settings tab 顶部标题：衬线大标题 + 斜体宋体副标 + 金色 hairline。
/// 5 个 settings tab 共用。
struct SettingsTabHeader: View {
    let zhTitle: String
    let enTitle: String
    let zhSubtitle: String
    let enSubtitle: String

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(lang == .zh ? zhTitle : enTitle)
                .font(.piloSerifTitle)
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)
            Text(lang == .zh ? zhSubtitle : enSubtitle)
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)

            // 金色 hairline 装饰
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.piloGold.opacity(0),
                                 Color.piloGold.opacity(0.6),
                                 Color.piloGold.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120, height: 1)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PiloSpacing.l)
        .padding(.bottom, PiloSpacing.s)
    }
}
