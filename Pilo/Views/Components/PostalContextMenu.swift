import SwiftUI

/// 邮局风右键 / 快捷菜单 popover —— 跟 AI launcher 同语调（cream paper + 金线）
/// 但更紧凑、无大标题（快速操作不需要仪式感）。
///
/// 单条 item = SF Symbol + label + 可选 trailing hint（如 keyboard shortcut）。
/// destructive 项支持 stampRed tint。
struct PostalContextMenu: View {

    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let icon: String          // SF Symbol
        let label: String
        let isDestructive: Bool
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
        .frame(width: 200)
        .background(
            // 双层：cream paper 主体 + 极淡 gold 内描边
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
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconTint)
                    .frame(width: 16, alignment: .center)
                Text(item.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
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
        .init(icon: "folder", label: "在 Finder 中显示", isDestructive: false, action: {}),
        .init(icon: "terminal", label: "在终端打开", isDestructive: false, action: {}),
        .init(icon: "doc.on.doc", label: "复制路径", isDestructive: false, action: {}),
        .separator(),
        .init(icon: "eye.slash", label: "隐藏此仓库", isDestructive: true, action: {}),
    ])
    .padding(40)
    .background(Color.creamBg)
}
