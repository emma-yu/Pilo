import SwiftUI
import AppKit

struct OnboardingFlow: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding.rawValue) private var hasCompletedOnboarding: Bool = false

    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, directories, privacy, complete
    }

    var body: some View {
        VStack(spacing: 0) {
            // 内容区，按 step 切换
            ZStack {
                switch step {
                case .welcome:
                    OnboardingWelcomeView(onContinue: { advance(to: .directories) })
                        .transition(.opacity)
                case .directories:
                    OnboardingDirectoriesView(
                        onContinue: { advance(to: .privacy) },
                        onSkip: { advance(to: .privacy) }
                    )
                    .transition(.opacity)
                case .privacy:
                    OnboardingPrivacyView(onContinue: { advance(to: .complete) })
                        .transition(.opacity)
                case .complete:
                    OnboardingCompleteView(onFinish: { finish(openMainWindow: true) })
                        .transition(.opacity)
                }
            }
            .animation(.piloSpring, value: step)

            PiloProgressBar(totalSteps: Step.allCases.count, currentStep: step.rawValue)
                .padding(.bottom, PiloSpacing.l)
        }
        .frame(width: 560, height: 480)
        .onAppear {
            // 切换到 .regular 让 Onboarding 窗口出现在 Dock 和 App Switcher
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // 还原到 .accessory（菜单栏 only）
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - 步骤切换

    private func advance(to next: Step) {
        step = next
    }

    private func finish(openMainWindow: Bool) {
        // 强制 UserDefaults sync，防 onboarding 完成后 app 立即崩或退出导致丢失
        hasCompletedOnboarding = true
        UserDefaults.standard.synchronize()

        if openMainWindow {
            openWindow(id: "main")
        }
        dismissWindow(id: "onboarding")
    }

}
