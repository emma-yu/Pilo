import SwiftUI

/// Privacy 屏 —— 邮局风手写承诺信（2026-05-14 视觉统一）
///
/// 复用 Pilo design system 已有 primitives，不引入新装饰：
///   - `HandDrawnUnderline`：headline 下手绘金线（手写承诺感）
///   - `SectionDivider`：金色斜体 label + 金色渐变线（跟"— 待寄出的小信 —"一致）
///   - `goldDark` 加粗 `·` bullet：跟 ReleaseLetterReaderView 的 highlight bullet 同款
///   - ✦ 金星 + Songti italic footer：像信尾"已签名"
///
/// 每段 Text 用 `.fixedSize(horizontal: false, vertical: true)`，
/// 杜绝 SwiftUI 在固定窗口下静默 truncate Text。
struct OnboardingPrivacyView: View {

    @Environment(AppState.self) private var appState
    let onContinue: () -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)

            // Privacy hero —— 爱心翅膀邮票（承诺贴在信件上）
            Image("PostalStamp")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-4))
                .shadow(color: Color.piloBlueDark.opacity(0.15), radius: 4, y: 3)

            Text(Copy.Onboarding.privacyTitle(lang))
                .font(.piloTitle)
                .tracking(-0.5)
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            privacyBodyCard

            Spacer()

            Button(action: onContinue) {
                Text(Copy.Onboarding.privacyAck(lang) + " →")
                    .font(.piloSection)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.piloPrimary)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 6)
        }
        .padding(30)
    }

    // MARK: - Body card

    /// 邮局风手写承诺信卡
    private var privacyBodyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            // 1. Headline + HandDrawnUnderline
            VStack(alignment: .leading, spacing: 3) {
                Text(Copy.Onboarding.privacyHeadline(lang))
                    .font(.custom("Songti SC", size: 16).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HandDrawnUnderline(width: 70, color: Color.piloGoldDark.opacity(0.5))
            }

            // 2. Promise（三段并列）
            Text(Copy.Onboarding.privacyPromise(lang))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 3. SectionDivider —— 金 italic label + 渐变金线
            SectionDivider(label: Copy.Onboarding.privacyExceptionsLabel(lang))
                .padding(.top, 2)

            // 4-6. Bullets（goldDark 加粗 · 跟信件 reader 同款）
            VStack(alignment: .leading, spacing: 5) {
                bulletRow(Copy.Onboarding.privacyBulletGit(lang))
                bulletRow(Copy.Onboarding.privacyBulletVisibility(lang))
                bulletRow(Copy.Onboarding.privacyBulletUpdate(lang))
            }
            .padding(.leading, 2)

            // 7. Footer —— ✦ 金星签名 + Songti italic
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("✦")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.piloGoldDark.opacity(0.6))
                Text(Copy.Onboarding.privacyOpenSource(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.paperCard)
                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        )
        .padding(.horizontal, 30)
    }

    /// 信件风 bullet —— 跟 ReleaseLetterReaderView highlight bullet 同款（goldDark 加粗 ·）
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("·")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.piloGoldDark.opacity(0.7))
                .frame(width: 8)
            Text(text)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
