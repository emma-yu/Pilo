import SwiftUI

/// 段式进度条：替代 Onboarding 的 4 个点。
/// N 段，已完成段填 PiloBlue，未完成段填 cloudDivider；段间留小 gap。
struct PiloProgressBar: View {
    let totalSteps: Int
    let currentStep: Int   // 0-based；currentStep 及之前都算"已完成或当前"

    var width: CGFloat = 240
    var height: CGFloat = 4

    @Environment(AppState.self) private var appState: AppState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lang: Language {
        appState?.language ?? .zh
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Capsule(style: .continuous)
                    .fill(idx <= currentStep ? Color.piloBlue : Color.cloudDivider)
                    .frame(height: height)
            }
        }
        .frame(width: width)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2)
                         : .spring(response: 0.4, dampingFraction: 0.85),
            value: currentStep
        )
        .accessibilityLabel(Copy.Onboarding.progressBarStep(lang, step: currentStep + 1, total: totalSteps))
    }
}

#Preview {
    VStack(spacing: 20) {
        PiloProgressBar(totalSteps: 4, currentStep: 0)
        PiloProgressBar(totalSteps: 4, currentStep: 1)
        PiloProgressBar(totalSteps: 4, currentStep: 2)
        PiloProgressBar(totalSteps: 4, currentStep: 3)
    }
    .padding()
    .background(Color.creamBg)
}
