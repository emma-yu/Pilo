import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.piloSection)
                .fontWeight(.semibold)
                .foregroundStyle(Color.inkPrimary)
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
