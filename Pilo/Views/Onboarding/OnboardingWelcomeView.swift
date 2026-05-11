import SwiftUI

struct OnboardingWelcomeView: View {

    @Environment(\.tone) private var tone
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 10)

            PiloMascot(mood: .happy, size: 96, breathing: true)

            Text(Copy.Onboarding.welcomeTitle)
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)

            Text(Copy.Onboarding.welcomeBody)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(symbol: "magnifyingglass", text: Copy.Onboarding.welcomeFeature1)
                featureRow(symbol: "shield.checkered", text: Copy.Onboarding.welcomeFeature2)
                featureRow(symbol: "lock.shield", text: Copy.Onboarding.welcomeFeature3)
            }
            .padding(.top, 8)
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

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.piloBlue)
                .frame(width: 20)
            Text(text)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
    }
}
