import SwiftUI

/// 用户点 finding 卡片上的"标记为误报"后，弹出让 ta 选范围。
/// v0.1 两档：仅此文件 / 整个仓库都不再扫这条规则。
struct FalsePositiveScopeSheet: View {

    let finding: ScanFinding
    let onPick: (FalsePositiveMark.Scope) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Scan.markFPTitle)
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
                Text(Copy.Scan.markFPSubtitle)
                    .font(.piloBody)
                    .foregroundStyle(Color.inkSecondary)
            }

            VStack(spacing: 8) {
                scopeButton(
                    title: Copy.Scan.markFPHere,
                    subtitle: "\(finding.filePath):\(finding.lineNumber) 的这个匹配不再提示",
                    symbol: "doc.text",
                    action: { onPick(.thisFileOnly) }
                )
                scopeButton(
                    title: Copy.Scan.markFPRule,
                    subtitle: finding.ruleName + "（整个仓库都跳过）",
                    symbol: "xmark.circle",
                    action: { onPick(.thisRule) }
                )
            }

            HStack {
                Spacer()
                Button(Copy.Scan.markFPCancel, action: onCancel)
                    .buttonStyle(.piloSecondary)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(Color.creamBg)
    }

    private func scopeButton(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.piloBlue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.piloSection)
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.paperCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.cloudDivider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloBlue.opacity(0.06), cornerRadius: 10)
    }
}
