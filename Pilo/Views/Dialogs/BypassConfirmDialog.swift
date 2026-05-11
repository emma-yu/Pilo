import SwiftUI

/// 用户尝试在有 critical findings 的情况下强推时弹出。
/// **必须输入仓库名才能解锁**——故意制造摩擦，防止误点。
struct BypassConfirmDialog: View {

    @Environment(\.tone) private var tone

    let expectedRepoName: String
    let criticalCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed: String = ""
    @FocusState private var isInputFocused: Bool

    var matches: Bool {
        typed.trimmingCharacters(in: .whitespaces) == expectedRepoName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                PiloMascot(mood: .worried, size: 64, breathing: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Scan.bypassConfirmTitle(tone))
                        .font(.piloTitle)
                        .foregroundStyle(Color.inkPrimary)
                    Text("发现 \(criticalCount) 项高危内容仍未处理")
                        .font(.piloBody)
                        .foregroundStyle(Color.roseDanger)
                }
                Spacer()
            }

            Text(Copy.Scan.bypassConfirmDesc)
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.roseDanger.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(expectedRepoName)
                    .font(.piloMono)
                    .foregroundStyle(Color.inkTertiary)
                TextField(Copy.Scan.bypassConfirmInputPlaceholder, text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        if matches { onConfirm() }
                    }
                if !typed.isEmpty && !matches {
                    Text(Copy.Scan.bypassNameMismatch)
                        .font(.piloCaption)
                        .foregroundStyle(Color.roseDanger)
                }
            }

            HStack {
                Button(Copy.Scan.bypassConfirmNo, action: onCancel)
                    .buttonStyle(.piloSecondary)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(Copy.Scan.bypassConfirmYes, action: onConfirm)
                    .buttonStyle(.piloDestructive)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!matches)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color.creamBg)
        .task {
            // 延迟 100ms 再 focus，让 sheet 完成出现动画后键盘焦点稳定
            try? await Task.sleep(nanoseconds: 100_000_000)
            isInputFocused = true
        }
    }
}
