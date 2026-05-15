import SwiftUI

/// 邮局风右键 / 快捷菜单 popover —— 跟 AI launcher 同语调（cream paper + 金线）
/// 但更紧凑、无大标题（快速操作不需要仪式感）。
///
/// **组件 features**：
///   - **左侧 ✓ 槽位**：toggle 项 `isActive=true` 时显示金色 ✓（Mac NSMenu `.on` 约定）
///     ✓ 槽位永远保留 → 所有 row 的图标 / 文字对齐
///   - **右侧 shortcut 提示**：item.shortcut 非空时 trailing 显示小灰字 e.g. "⌘E"
///     **honest UI house rule**：只在 shortcut 真实 wired 时填，否则别写假提示
///   - **destructive** 项：`stampRed` tint，hover 红泛
///   - **separator**：金色 leading→trailing 渐变 hairline，不是普通直线
struct PostalContextMenu: View {

    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let icon: String          // SF Symbol
        let label: String
        let isDestructive: Bool
        /// 当前激活状态——显示左侧 ✓（Mac NSMenu `.on` state 约定）
        /// 推荐用法：toggle 项使用稳定 label + `isActive` 切；
        /// 不推荐：flipped label（"钉住"/"取消钉住"）+ `isActive` 同时用 → 信息冗余。
        var isActive: Bool = false
        /// Trailing 小灰字 keyboard shortcut hint，e.g. "⌘E" / "⌫"。
        /// **honest UI rule**：仅在实际 wired 时填，假提示比无提示更糟。
        var shortcut: String? = nil
        let action: () -> Void
        /// nil = 分隔线（icon / label / action 都忽略）
        var isSeparator: Bool = false

        static func separator() -> Item {
            Item(icon: "", label: "", isDestructive: false, action: {}, isSeparator: true)
        }
    }

    @State private var hoveredID: UUID?

    var body: some View {
        VStack(spacing: 1) {
            ForEach(items) { item in
                if item.isSeparator {
                    separator
                } else {
                    row(item)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.piloPaper.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.piloGold.opacity(0),
                        Color.piloGold.opacity(0.5),
                        Color.piloGold.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private func row(_ item: Item) -> some View {
        let isHovered = hoveredID == item.id
        let tint: Color = item.isDestructive ? .stampRed : .inkPrimary
        let iconTint: Color = item.isDestructive ? .stampRed : .piloGoldDark

        return Button(action: item.action) {
            HStack(spacing: 0) {
                // ✓ 槽位 —— 永远保留宽度，保持所有行 icon/label 对齐
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.piloGoldDark)
                    .opacity(item.isActive ? 1 : 0)
                    .frame(width: 12, alignment: .center)

                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconTint)
                    .frame(width: 16, alignment: .center)
                    .padding(.leading, 4)

                Text(item.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.leading, 8)

                Spacer(minLength: 8)

                if let s = item.shortcut, !s.isEmpty {
                    Text(s)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovered
                            ? (item.isDestructive
                               ? Color.stampRed.opacity(0.10)
                               : Color.piloGold.opacity(0.10))
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredID = hovering ? item.id : nil
        }
    }
}

#Preview {
    PostalContextMenu(items: [
        .init(icon: "pencil", label: "编辑", isDestructive: false, shortcut: "⌘E", action: {}),
        .init(icon: "pin", label: "钉住", isDestructive: false, isActive: true, action: {}),
        .init(icon: "star.fill", label: "钉到首位 ✦", isDestructive: false, isActive: true, action: {}),
        .init(icon: "doc.on.doc", label: "誊抄", isDestructive: false, shortcut: "⌘C", action: {}),
        .separator(),
        .init(icon: "eye.slash", label: "隐藏此仓库", isDestructive: true, action: {}),
        .init(icon: "trash", label: "删除", isDestructive: true, shortcut: "⌫", action: {}),
    ])
    .padding(40)
    .background(Color.creamBg)
}
