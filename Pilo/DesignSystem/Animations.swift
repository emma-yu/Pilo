import SwiftUI

extension Animation {
    static let piloSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    static func piloRespectMotion(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .piloSpring
    }
}
