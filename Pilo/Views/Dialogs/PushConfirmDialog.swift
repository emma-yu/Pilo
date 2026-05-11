import SwiftUI
import AppKit

/// 推送确认 sheet。三态：preflight / running / completed。
/// 安全检查区域 Phase 6 启用，当前显示占位。
struct PushConfirmDialog: View {

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var session: PushSession?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch session?.state {
            case .preflight(let pre):
                preflightView(pre)
            case .running(let r):
                runningView(remote: r.remote)
            case .completed(let report):
                completedView(report)
            case .none:
                EmptyView()
            }
        }
        .frame(width: 540)
        .frame(minHeight: 360)
        .background(Color.creamBg)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Preflight

    @ViewBuilder
    private func preflightView(_ pre: PushSession.Preflight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            preflightHeader(pre)
            Divider()
            commitsList(pre.commits)
            scanPlaceholder
            Spacer(minLength: 0)
            preflightFooter(pre)
        }
        .padding(24)
    }

    private func preflightHeader(_ pre: PushSession.Preflight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Copy.Push.preflightTitle(tone))
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            Text(Copy.Push.preflightSubtitle(tone, count: pre.commits.count))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)

            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.piloBlue)
                Text(pre.repoName)
                    .font(.piloSection)
                Text("·")
                    .foregroundStyle(Color.inkTertiary)
                Text(pre.branch)
                    .font(.piloMono)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.cloudDivider.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.inkTertiary)
                Text(pre.remote)
                    .font(.piloMono)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.piloBlueLight.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.top, 4)

            if pre.willSetUpstream {
                Label(Copy.Push.preflightFirstPushHint, systemImage: "info.circle")
                    .font(.piloCaption)
                    .foregroundStyle(Color.lavenderInfo)
            }
        }
    }

    private func commitsList(_ commits: [CommitSummary]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: Copy.Push.preflightCommitsHeader, trailing: "\(commits.count)")
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(commits) { c in
                        HStack(alignment: .top, spacing: 8) {
                            Text(c.hash)
                                .font(.piloMono)
                                .foregroundStyle(Color.piloBlue)
                                .frame(width: 64, alignment: .leading)
                            Text(c.subject)
                                .font(.piloBody)
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.paperCard)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            )
        }
    }

    private var scanPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(Color.inkTertiary)
            Text(Copy.Push.preflightScanPlaceholder)
                .font(.piloCaption)
                .foregroundStyle(Color.inkTertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.cloudDivider, lineWidth: 1)
        )
    }

    private func preflightFooter(_ pre: PushSession.Preflight) -> some View {
        HStack {
            Button(Copy.Push.cancelButton(tone), action: onDismiss)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                Task { await appState.executePush() }
            } label: {
                Text(Copy.Push.pushButton(tone))
                    .frame(minWidth: 110)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Color.piloBlue)
            .keyboardShortcut(.defaultAction)
            .disabled(pre.commits.isEmpty)
        }
    }

    // MARK: - Running

    @ViewBuilder
    private func runningView(remote: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            if reduceMotion {
                PiloMascot(mood: .flying, size: 80)
            } else {
                FlyingPiloAnimation()
            }
            Text(Copy.Push.runningTitle(tone, remote: remote))
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Completed

    @ViewBuilder
    private func completedView(_ report: PushReport) -> some View {
        if report.outcome.isSuccess {
            successView(report)
        } else {
            failureView(report)
        }
    }

    private func successView(_ report: PushReport) -> some View {
        VStack(spacing: 14) {
            Spacer()
            PiloMascot(mood: .happy, size: 80)
            Text(Copy.Push.successTitle(tone))
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            Text(Copy.Push.successSubtitle(tone, count: report.commitCount))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Button(Copy.Push.doneButton, action: onDismiss)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color.piloBlue)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }

    private func failureView(_ report: PushReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PiloMascot(mood: .worried, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Push.failureTitle(tone, outcome: report.outcome))
                        .font(.piloTitle)
                        .foregroundStyle(Color.inkPrimary)
                    Text(Copy.Push.failureExplanation(report.outcome))
                        .font(.piloBody)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            if !report.outcome.stderrTrimmed.isEmpty {
                ScrollView {
                    Text(report.outcome.stderrTrimmed)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.cloudDivider.opacity(0.3))
                )
            }

            HStack {
                Button(Copy.Push.copyStderrButton) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(report.outcome.stderrTrimmed, forType: .string)
                }
                Button(Copy.Push.openTerminalButton) {
                    openTerminal(at: appState.repositories.first(where: { $0.id == report.repoId })?.path)
                }
                Spacer()
                Button(Copy.Push.closeButton, action: onDismiss)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.piloBlue)
            }
        }
        .padding(24)
    }

    private func openTerminal(at path: String?) {
        guard let path else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open([url],
                                withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                configuration: NSWorkspace.OpenConfiguration(),
                                completionHandler: nil)
    }
}

// MARK: - 飞行动画

/// 简化版的"小信鸽飞出去"，遵守 Reduce Motion 时由父视图改用静态图标。
private struct FlyingPiloAnimation: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        PiloMascot(mood: .flying, size: 80)
            .offset(y: -10 * sin(phase * .pi * 2))
            .rotationEffect(.degrees(Double(sin(phase * .pi * 4) * 6)))
            .task {
                // 简单的正弦上下浮动；不依赖 SwiftUI 内置 spring，避免和外层 sheet 动画打架
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    phase += 0.012
                    if phase > 1 { phase -= 1 }
                }
            }
    }
}
