import SwiftUI

struct OnboardingDirectoriesView: View {

    @Environment(AppState.self) private var appState

    // 100ms 延迟解锁按钮，避免 Window 出现瞬间 NSOpenPanel 触发 dock 闪烁
    @State private var addEnabled: Bool = false

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            PiloMascot(mood: .alert, size: 64)

            Text(Copy.Onboarding.directoriesTitle)
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)

            directoryList

            Text(Copy.Onboarding.directoriesHint)
                .font(.piloCaption)
                .foregroundStyle(Color.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Spacer()

            HStack(spacing: 12) {
                Button(Copy.Onboarding.directoriesSkip, action: onSkip)
                    .controlSize(.large)

                Spacer()

                Button(action: onContinue) {
                    Text(Copy.Onboarding.directoriesNext + " →")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color.piloBlue)
                .disabled(appState.watchDirectories.isEmpty)
                .keyboardShortcut(.defaultAction)
            }

            Spacer(minLength: 8)
        }
        .padding(30)
        .task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            addEnabled = true
        }
    }

    private var directoryList: some View {
        VStack(spacing: 8) {
            if appState.watchDirectories.isEmpty {
                emptyRow
            } else {
                ForEach(appState.watchDirectories, id: \.self) { url in
                    directoryRow(url: url)
                }
            }
            Button(action: addDirectory) {
                Label(Copy.Onboarding.directoriesAdd, systemImage: "plus")
                    .font(.piloBody)
            }
            .buttonStyle(.borderless)
            .disabled(!addEnabled)
            .padding(.top, 4)
        }
        .frame(maxWidth: 400)
    }

    private var emptyRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(Color.inkTertiary)
            Text(Copy.Onboarding.directoriesEmpty)
                .font(.piloBody)
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.cloudDivider.opacity(0.5))
        )
    }

    private func directoryRow(url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(Color.piloBlue)
            Text(url.path)
                .font(.piloMono)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                appState.removeWatchDirectory(url)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.roseDanger)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("移除目录")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.paperCard)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        )
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "选择 Pilo 要扫描的根目录"
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            for url in panel.urls {
                appState.addWatchDirectory(url)
            }
        }
    }
}
