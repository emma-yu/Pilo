import SwiftUI

struct OnboardingPrivacyView: View {

    @Environment(AppState.self) private var appState
    let onContinue: () -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            PiloMascot(mood: .alert, size: 110, breathing: true)

            Text(Copy.Onboarding.privacyTitle(lang))
                .font(.piloHero)
                .tracking(-0.5)
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Text(Copy.Onboarding.privacyBody(lang))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.paperCard)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                )
                .padding(.horizontal, 30)
                .frame(maxWidth: 460)

            Spacer()

            Button(action: onContinue) {
                Text(Copy.Onboarding.privacyAck(lang) + " →")
                    .font(.piloSection)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.piloPrimary)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 8)
        }
        .padding(30)
    }
}
