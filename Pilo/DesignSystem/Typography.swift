import SwiftUI

extension Font {
    /// Hero——onboarding / 空态主标题
    static let piloHero     = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let piloTitle    = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let piloSection  = Font.system(size: 15, weight: .medium,   design: .rounded)
    static let piloBody     = Font.system(size: 13, weight: .regular,  design: .default)
    /// 分区标签——10pt uppercase tracked，用于轻量分组
    static let piloLabel    = Font.system(size: 10, weight: .semibold, design: .default)
    static let piloCaption  = Font.system(size: 11, weight: .regular,  design: .default)
    static let piloMono     = Font.system(size: 12, weight: .regular,  design: .monospaced)
}
