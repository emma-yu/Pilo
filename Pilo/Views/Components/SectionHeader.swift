import SwiftUI

struct SectionHeader: View {
    enum Style {
        case standard   // piloSection 15pt rounded medium
        case label      // 10pt uppercase tracked，用于轻量分组
    }

    let title: String
    var trailing: String?
    var style: Style = .standard

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(style == .label ? title.uppercased() : title)
                .font(style == .label ? .piloLabel : .piloSection)
                .fontWeight(.semibold)
                .tracking(style == .label ? 1.0 : 0)
                .foregroundStyle(style == .label ? Color.inkSecondary : Color.inkPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.piloCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }
}
