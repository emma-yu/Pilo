import SwiftUI

struct OnboardingCompleteView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            PiloMascot(mood: .happy, size: 96, breathing: true)

            primaryText

            if let v = appState.gitVersion, let p = appState.gitExecutablePath {
                Text(String(format: Copy.Onboarding.completeGitInfo, v, p))
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(Copy.Onboarding.completeNoGit)
                    .font(.piloCaption)
                    .foregroundStyle(Color.amberWarn)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: onFinish) {
                    Text(Copy.Onboarding.completeOpen)
                        .font(.piloSection)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.piloPrimary)
                .keyboardShortcut(.defaultAction)

                Text(Copy.Onboarding.completeStayInMenubar)
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
            }

            Spacer(minLength: 10)
        }
        .padding(30)
    }

    private var primaryText: some View {
        Group {
            if appState.isScanning {
                Text(Copy.menubarScanInProgress(tone))
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
            } else if appState.repositories.isEmpty {
                Text(Copy.Onboarding.completeTitleEmpty)
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
            } else {
                Text(String(format: Copy.Onboarding.completeTitleFound, appState.repositories.count))
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
            }
        }
    }
}
