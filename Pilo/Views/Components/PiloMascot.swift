import SwiftUI

/// Pilo 小信鸽形象。v0.1 阶段全部用 SF Symbol 占位（PRD §9 第 3 条允许），
/// 真实 SVG 资产由 Emma 后续提供。每个 mood 必须有 accessibilityLabel（无障碍硬要求）。
struct PiloMascot: View {

    enum Mood: String, CaseIterable, Sendable {
        case sleeping
        case alert
        case worried
        case happy
        case raining
        case flying
        case sunglasses

        var sfSymbol: String {
            switch self {
            case .sleeping:   "bird.fill"
            case .alert:      "bird.fill"
            case .worried:    "bird.fill"
            case .happy:      "bird.fill"
            case .raining:    "umbrella.fill"
            case .flying:     "paperplane.fill"
            case .sunglasses: "sunglasses.fill"
            }
        }

        var tint: Color {
            switch self {
            case .sleeping:   .inkTertiary
            case .alert:      .piloBlue
            case .worried:    .amberWarn
            case .happy:      .mintSafe
            case .raining:    .lavenderInfo
            case .flying:     .piloBlue
            case .sunglasses: .inkPrimary
            }
        }
    }

    let mood: Mood
    var size: CGFloat = 64

    @Environment(\.tone) private var tone

    var body: some View {
        Image(systemName: mood.sfSymbol)
            .font(.system(size: size * 0.7, weight: .regular))
            .foregroundStyle(mood.tint)
            .frame(width: size, height: size)
            .accessibilityLabel(Copy.MascotA11y.label(for: mood, tone: tone))
    }
}

#Preview("All moods") {
    VStack(spacing: 16) {
        ForEach(PiloMascot.Mood.allCases, id: \.self) { mood in
            HStack {
                PiloMascot(mood: mood, size: 48)
                Text(mood.rawValue)
                    .font(.piloBody)
            }
        }
    }
    .padding()
    .frame(width: 280)
}
