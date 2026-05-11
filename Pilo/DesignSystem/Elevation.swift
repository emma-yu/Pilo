import SwiftUI

/// Pilo v2 阴影系统：三档「浮起」感，仿 Dribbble / Linear 等现代 macOS app。
/// 单层 vs 双层选择标准：
///   - subtle：单层即可（仅 hover 临时反馈用）
///   - normal：单层，全局卡片默认
///   - elevated：**双层**（紧贴 + 环境），用于 hero / 选中 / sheet header
enum Elevation {
    case subtle
    case normal
    case elevated

    /// 应用到任何 View（一次性）
    func apply<V: View>(to view: V) -> some View {
        Group {
            switch self {
            case .subtle:
                view.shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            case .normal:
                view.shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            case .elevated:
                // 双层：紧贴 + 环境
                view
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    .shadow(color: .black.opacity(0.04), radius: 24, y: 8)
            }
        }
    }
}

extension View {
    /// `.elevation(.normal)` 链式调用
    func elevation(_ level: Elevation) -> some View {
        level.apply(to: self)
    }
}
