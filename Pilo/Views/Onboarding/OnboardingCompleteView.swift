import SwiftUI

struct OnboardingCompleteView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    let onFinish: () -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: PiloSpacing.l) {
            Spacer(minLength: PiloSpacing.s)

            ZStack(alignment: .topTrailing) {
                PiloMascot(mood: .happy, size: 140, breathing: true)
                WaxSeal(size: 48, label: "READY")
                    .offset(x: 8, y: -4)
            }

            primaryText

            if let v = appState.gitVersion, let p = appState.gitExecutablePath {
                Text(String(format: Copy.Onboarding.completeGitInfo(lang), v, p))
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(Copy.Onboarding.completeNoGit(lang))
                    .font(.piloCaption)
                    .foregroundStyle(Color.amberWarn)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: onFinish) {
                    Text(Copy.Onboarding.completeOpen(lang))
                        .font(.piloSection)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.piloPrimary)
                .keyboardShortcut(.defaultAction)

                Text(Copy.Onboarding.completeStayInMenubar(lang))
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
            }

            // 工作室署名（cross-promo step 1）——金线齿孔 + Songti 10pt 灰署名。
            // 这是 brand 署名而不是 feature checklist，保留。
            VStack(spacing: 5) {
                PerforationLine(width: 64)
                Text(Copy.Studio.attributionShort(lang))
                    .font(.custom("Songti SC", size: 10).italic())
                    .foregroundStyle(Color.inkTertiary.opacity(0.45))
                    .tracking(0.5)
            }

            Spacer(minLength: 10)
        }
        .padding(30)
    }

    private var primaryText: some View {
        Group {
            if appState.isScanning {
                Text(Copy.menubarScanInProgress(tone))
                    .font(.piloHero)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.8)
            } else if appState.repositories.isEmpty {
                Text(Copy.Onboarding.completeTitleEmpty(lang))
                    .font(.piloHero)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.8)
            } else {
                Text(String(format: Copy.Onboarding.completeTitleFound(lang), appState.repositories.count))
                    .font(.piloHero)
                    .foregroundStyle(Color.inkPrimary)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}
