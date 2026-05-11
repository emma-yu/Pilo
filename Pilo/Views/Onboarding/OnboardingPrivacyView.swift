import SwiftUI

struct OnboardingPrivacyView: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            PiloMascot(mood: .alert, size: 64)

            Text(Copy.Onboarding.privacyTitle)
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)

            Text(Copy.Onboarding.privacyBody)
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
                Text(Copy.Onboarding.privacyAck + " →")
                    .frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Color.piloBlue)
            .keyboardShortcut(.defaultAction)

            Spacer(minLength: 8)
        }
        .padding(30)
    }
}
