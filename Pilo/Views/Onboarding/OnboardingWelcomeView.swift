import SwiftUI

struct OnboardingWelcomeView: View {

    @Environment(\.tone) private var tone
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: PiloSpacing.l) {
            Spacer(minLength: PiloSpacing.s)

            // Hero with sparkle decorations
            ZStack {
                SparkleCluster(mascotSize: 96)
                PiloMascot(mood: .happy, size: 96, breathing: true)
            }

            Text(Copy.Onboarding.welcomeTitle)
                .font(.piloHero)
                .foregroundStyle(Color.inkPrimary)

            Text(Copy.Onboarding.welcomeBody)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PiloSpacing.xl)

            VStack(alignment: .leading, spacing: PiloSpacing.m) {
                featureRow(symbol: "magnifyingglass", text: Copy.Onboarding.welcomeFeature1, tint: .piloBlue)
                featureRow(symbol: "shield.checkered", text: Copy.Onboarding.welcomeFeature2, tint: .piloAccent)
                featureRow(symbol: "lock.shield", text: Copy.Onboarding.welcomeFeature3, tint: .mintSafe)
            }
            .padding(.top, PiloSpacing.s)
            .frame(maxWidth: 380, alignment: .leading)

            Spacer()

            Button(action: onContinue) {
                Text(Copy.Onboarding.welcomeContinue + " →")
                    .font(.piloSection)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.piloPrimary)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 10)
        }
        .padding(30)
    }

    private func featureRow(symbol: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: PiloSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(text)
                .font(.piloBody)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
    }
}
