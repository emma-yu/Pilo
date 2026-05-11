import SwiftUI

/// v3.3 邮局风：装饰金线 + 衬线标题 + 引言斜体宋体 + 3 列 feature 卡 + 主 CTA
struct OnboardingWelcomeView: View {

    @Environment(\.tone) private var tone
    @Environment(AppState.self) private var appState
    let onContinue: () -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: PiloSpacing.l) {
            Spacer(minLength: 0)

            OrnamentDivider(width: 240)
                .padding(.bottom, PiloSpacing.xs)

            PiloMascot(mood: .happy, size: 120, breathing: true)

            VStack(spacing: PiloSpacing.xs) {
                Text(lang == .zh ? "Pilo 邮局" : "Pilo Post Office")
                    .font(.piloSerifHero)
                    .tracking(1.0)
                    .foregroundStyle(Color.inkPrimary)
                Text(lang == .zh ? "— 你好呀，我是 Pilo · 咕咕 —"
                                  : "— Hi there, I'm Pilo · coo coo —")
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkSecondary)
            }

            quote
                .padding(.top, PiloSpacing.xs)

            featureGrid
                .padding(.top, PiloSpacing.s)

            Button(action: onContinue) {
                Text(Copy.Onboarding.welcomeContinue(lang))
                    .font(.piloSection)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.piloPrimary)
            .keyboardShortcut(.defaultAction)
            .padding(.top, PiloSpacing.s)

            Spacer(minLength: 0)
        }
        .padding(PiloSpacing.xl)
    }

    private var quote: some View {
        Text(lang == .zh
             ? "「从今天起，我会替你\n把代码安全送达 GitHub 那一端。」"
             : "“From today on, I'll deliver your code\nsafely to the GitHub side.”")
            .font(.piloSerifSubtitle)
            .foregroundStyle(Color.piloBlue)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
    }

    private var featureGrid: some View {
        HStack(spacing: PiloSpacing.s) {
            featureCard(
                symbol: "magnifyingglass.circle.fill",
                tint: .piloBlue,
                title: lang == .zh ? "自动寻找" : "Auto-find",
                desc: lang == .zh ? "认识所有仓库" : "Knows all repos"
            )
            featureCard(
                symbol: "shield.lefthalf.filled",
                tint: .mintSafe,
                title: lang == .zh ? "温柔检查" : "Gentle scan",
                desc: lang == .zh ? "不让 key 偷溜" : "Stops leaks"
            )
            featureCard(
                symbol: "paperplane.fill",
                tint: .roseDanger,
                title: lang == .zh ? "一键飞翔" : "One-tap fly",
                desc: lang == .zh ? "咕～送达" : "Coo~ delivered"
            )
        }
        .frame(maxWidth: 440)
    }

    private func featureCard(symbol: String, tint: Color, title: String, desc: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
            Text(desc)
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PiloSpacing.m)
        .padding(.horizontal, PiloSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaperBorder.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.piloPaperBorder, lineWidth: 0.5)
                )
        )
    }
}
