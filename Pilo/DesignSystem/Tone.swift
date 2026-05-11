import SwiftUI

enum Tone: String, CaseIterable, Sendable, Codable {
    case friendly
    case minimal

    var displayName: String {
        switch self {
        case .friendly: "Friendly · 温柔模式"
        case .minimal: "Minimal · 极简模式"
        }
    }
}

private struct ToneEnvironmentKey: EnvironmentKey {
    static let defaultValue: Tone = .friendly
}

extension EnvironmentValues {
    var tone: Tone {
        get { self[ToneEnvironmentKey.self] }
        set { self[ToneEnvironmentKey.self] = newValue }
    }
}

extension View {
    func tone(_ tone: Tone) -> some View {
        environment(\.tone, tone)
    }
}
