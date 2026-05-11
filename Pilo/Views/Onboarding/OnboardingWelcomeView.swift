import SwiftUI

struct OnboardingWelcomeView: View {

    @Environment(\.tone) private var tone
    @Environment(AppState.self) private var appState
    let onContinue: () -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: PiloSpacing.xl) {
            Spacer()

            PiloMascot(mood: .happy, size: 140, breathing: true)

            VStack(spacing: PiloSpacing.m) {
                Text(Copy.Onboarding.welcomeTitle(lang))
                    .font(.piloHero)
                    .tracking(-0.5)
                    .foregroundStyle(Color.inkPrimary)

                Text(Copy.Onboarding.welcomeBody(lang))
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }

            VStack(alignment: .leading, spacing: PiloSpacing.m) {
                featureRow(symbol: "magnifyingglass", text: Copy.Onboarding.welcomeFeature1(lang))
                featureRow(symbol: "shield.checkered", text: Copy.Onboarding.welcomeFeature2(lang))
                featureRow(symbol: "lock.shield", text: Copy.Onboarding.welcomeFeature3(lang))
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(.top, PiloSpacing.s)

            Spacer()

            Button(action: onContinue) {
                Text(Copy.Onboarding.welcomeContinue(lang) + " →")
                    .font(.piloSection)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.piloPrimary)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 10)
        }
        .padding(30)
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: PiloSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.piloBlue)
                .frame(width: 22)
            Text(text)
                .font(.piloBody)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
    }
}
