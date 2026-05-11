import SwiftUI

/// **向后兼容包装**：所有 callers 仍可用 StatusBadge(kind:)，内部转调 PiloChip。
/// 新代码推荐直接用 PiloChip。
struct StatusBadge: View {
    enum Kind {
        case ahead(Int)
        case behind(Int)
        case uncommitted(Int)
        case synced
        case offline

        var icon: String {
            switch self {
            case .ahead:        "arrow.up"
            case .behind:       "arrow.down"
            case .uncommitted:  "pencil"
            case .synced:       "checkmark"
            case .offline:      "wifi.slash"
            }
        }

        var label: String {
            switch self {
            case .ahead(let n):        "\(n)"
            case .behind(let n):       "\(n)"
            case .uncommitted(let n):  "\(n) 待提交"
            case .synced:              "已同步"
            case .offline:             "离线"
            }
        }

        var tint: Color {
            switch self {
            case .ahead:        .amberWarn
            case .behind:       .lavenderInfo
            case .uncommitted:  .roseDanger
            case .synced:       .mintSafe
            case .offline:      .inkTertiary
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .ahead(let n):        "比远端多 \(n) 个 commit"
            case .behind(let n):       "比远端少 \(n) 个 commit"
            case .uncommitted(let n):  "\(n) 个未提交文件"
            case .synced:              "已同步"
            case .offline:             "离线"
            }
        }
    }

    let kind: Kind

    var body: some View {
        PiloChip(icon: kind.icon, text: kind.label, tint: kind.tint, style: .tinted, size: .small)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind.accessibilityLabel)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StatusBadge(kind: .ahead(2))
        StatusBadge(kind: .behind(1))
        StatusBadge(kind: .uncommitted(5))
        StatusBadge(kind: .synced)
        StatusBadge(kind: .offline)
    }
    .padding()
    .background(Color.creamBg)
}
