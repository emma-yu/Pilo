import SwiftUI
import AppKit

/// "加入 .gitignore" 之后弹出，**诚实告知**用户：这次 push 已经包含的文件不会因为加入 .gitignore 而消失。
///
/// 这个 sheet 是 Phase 7 的诚信担当——Pilo 不能让用户以为点了按钮问题就解决了。
struct GitignoreActionSheet: View {

    let action: AppState.GitignoreActionState
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PiloMascot(mood: action.kind.isCritical ? .worried : .alert, size: 56, breathing: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Guard.actionSheetTitle)
                        .font(.piloTitle)
                        .foregroundStyle(Color.inkPrimary)
                    Text(action.filePath)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            addedSummary

            // 关键警示
            Text(action.advisedAction)
                .font(.piloBody)
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(action.kind.isCritical
                              ? Color.roseDanger.opacity(0.08)
                              : Color.piloCream.opacity(0.6))
                )

            HStack(spacing: 10) {
                Button(Copy.Guard.actionSheetOpen) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: action.gitignorePath))
                }
                .buttonStyle(.piloSecondary)

                if action.kind == .envFile || action.kind == .privateKey {
                    Button(Copy.Guard.actionSheetCopyFilterCmd) {
                        let cmd = "git filter-repo --path \(action.filePath) --invert-paths"
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(cmd, forType: .string)
                    }
                    .buttonStyle(.piloSecondary)
                }

                Spacer()

                Button(Copy.Guard.actionSheetDone, action: onDismiss)
                    .buttonStyle(.piloPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Color.creamBg)
    }

    @ViewBuilder
    private var addedSummary: some View {
        if !action.addedLines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.mintSafe)
                    Text("已追加 \(action.addedLines.count) 条规则到 .gitignore：")
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
                ForEach(action.addedLines, id: \.self) { line in
                    Text(line)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.leading, 18)
                }
            }
        } else if !action.alreadyPresent.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.inkTertiary)
                Text(".gitignore 里已经有这些规则了，未重复追加")
                    .font(.piloCaption)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }
}

private extension CommitGuardFinding.Kind {
    var isCritical: Bool {
        switch self {
        case .envFile, .privateKey, .oversizeBlocked: true
        default: false
        }
    }
}
