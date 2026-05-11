import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }
}
