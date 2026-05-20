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

        func label(lang: Language) -> String {
            switch self {
            case .ahead(let n):        "\(n)"
            case .behind(let n):       "\(n)"
            case .uncommitted(let n):  lang == .zh ? "\(n) 待提交" : "\(n) uncommitted"
            case .synced:              lang == .zh ? "已同步" : "Synced"
            case .offline:             lang == .zh ? "离线" : "Offline"
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

        func accessibilityLabel(lang: Language) -> String {
            switch self {
            case .ahead(let n):        lang == .zh ? "比远端多 \(n) 个 commit" : "\(n) commits ahead"
            case .behind(let n):       lang == .zh ? "比远端少 \(n) 个 commit" : "\(n) commits behind"
            case .uncommitted(let n):  lang == .zh ? "\(n) 个未提交文件" : "\(n) uncommitted files"
            case .synced:              lang == .zh ? "已同步" : "Synced"
            case .offline:             lang == .zh ? "离线" : "Offline"
            }
        }
    }

    let kind: Kind
    @Environment(AppState.self) private var appState

    var body: some View {
        PiloChip(icon: kind.icon, text: kind.label(lang: appState.language), tint: kind.tint, style: .tinted, size: .small)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(kind.accessibilityLabel(lang: appState.language))
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
