import SwiftUI

struct StatusBadge: View {
    enum Kind {
        case ahead(Int)
        case behind(Int)
        case uncommitted(Int)
        case synced
        case offline

        var tint: Color {
            switch self {
            case .ahead:        .amberWarn
            case .behind:       .lavenderInfo
            case .uncommitted:  .roseDanger
            case .synced:       .mintSafe
            case .offline:      .inkTertiary
            }
        }

        var label: String {
            switch self {
            case .ahead(let n):        "\(n) ↑"
            case .behind(let n):       "\(n) ↓"
            case .uncommitted(let n):  "\(n) 待提交"
            case .synced:              "同步"
            case .offline:             "离线"
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
        HStack(spacing: 5) {
            Circle()
                .fill(kind.tint)
                .frame(width: 8, height: 8)
            Text(kind.label)
                .font(.piloCaption)
                .fontWeight(.medium)
                .foregroundStyle(kind.tint.opacity(0.95))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(kind.tint.opacity(0.16))
        )
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
}
