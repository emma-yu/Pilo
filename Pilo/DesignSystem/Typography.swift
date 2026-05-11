import SwiftUI

extension Font {
    // 圆体——按钮、UI 元素、菜单栏
    static let piloHero     = Font.system(size: 36, weight: .semibold, design: .rounded)
    static let piloTitle    = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let piloSection  = Font.system(size: 17, weight: .medium,   design: .rounded)
    static let piloBody     = Font.system(size: 15, weight: .regular,  design: .default)
    static let piloLabel    = Font.system(size: 10, weight: .semibold, design: .default)
    static let piloCaption  = Font.system(size: 12, weight: .regular,  design: .default)
    static let piloMono     = Font.system(size: 13, weight: .regular,  design: .monospaced)

    // v3.3 邮局衬线——hero 标题、副标题、装饰标签
    /// 衬线大标题——hero 区主标题（"Pilo 邮局"、仓库名等）
    static let piloSerifHero     = Font.custom("Songti SC", size: 28).weight(.medium)
    /// 衬线标题
    static let piloSerifTitle    = Font.custom("Songti SC", size: 22).weight(.medium)
    /// 衬线副标题（斜体）——letterpress 信笺感
    static let piloSerifSubtitle = Font.custom("Songti SC", size: 13).italic()
    /// 衬线 section 标签（斜体）——"— 待寄出的小信 —"
    static let piloSerifLabel    = Font.custom("Songti SC", size: 12).italic()
    /// 衬线小注（斜体）——"— 3 天前"、"已沉睡 30 天" 等
    static let piloSerifCaption  = Font.custom("Songti SC", size: 11).italic()
}
