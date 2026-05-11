import CoreGraphics

/// 严格 8pt 网格的命名间距（仅 `m=12` 一个非倍数，用作中等节奏）。
/// 所有视图代码尽量用这些常量而非散裸数字，保证后续整体调节只改一处。
enum PiloSpacing {
    static let xs:   CGFloat = 4
    static let s:    CGFloat = 8
    static let m:    CGFloat = 12
    static let l:    CGFloat = 16
    static let xl:   CGFloat = 24
    static let xxl:  CGFloat = 32
    static let xxxl: CGFloat = 48
}

/// 命名圆角，对齐 Pilo v2 设计语言（详见 plan 文件）。
enum PiloRadius {
    static let chip:    CGFloat = 999   // pill 半圆头
    static let button:  CGFloat = 10
    static let card:    CGFloat = 16
    static let sheet:   CGFloat = 18
    static let small:   CGFloat = 6
}
