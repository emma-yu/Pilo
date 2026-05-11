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

    @State private var showBypassDialog = false

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
        .frame(width: 560)
        .frame(minHeight: 420)
        .background(Color.creamBg)
        .accessibilityElement(children: .contain)
        // BypassConfirmDialog — 仅当 critical findings 存在且用户主动点了"我已了解仍然推送"
        .sheet(isPresented: $showBypassDialog) {
            if let session, case .preflight(let pre) = session.state {
                BypassConfirmDialog(
                    expectedRepoName: pre.repoName,
                    criticalCount: pre.criticalFindings.count,
                    onConfirm: {
                        appState.confirmBypassForCurrentPush()
                        showBypassDialog = false
                        Task { await appState.executePush() }
                    },
                    onCancel: { showBypassDialog = false }
                )
            }
        }
        // FalsePositive 范围选择器
        .sheet(item: Binding(
            get: { appState.falsePositivePickerTarget },
            set: { appState.falsePositivePickerTarget = $0 }
        )) { finding in
            FalsePositiveScopeSheet(
                finding: finding,
                onPick: { scope in
                    Task { await appState.markFalsePositive(finding, scope: scope) }
                },
                onCancel: { appState.falsePositivePickerTarget = nil }
            )
        }
        // Phase 7：加入 .gitignore 之后的诚实告知 sheet
        .sheet(item: Binding(
            get: { appState.lastGitignoreAction },
            set: { appState.lastGitignoreAction = $0 }
        )) { action in
            GitignoreActionSheet(
                action: action,
                onDismiss: { appState.lastGitignoreAction = nil }
            )
        }
    }

    // MARK: - Preflight

    @ViewBuilder
    private func preflightView(_ pre: PushSession.Preflight) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            preflightHeader(pre)
            Divider()
            commitsList(pre.commits)
            findingsSection(pre)
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

    // MARK: - 检查总区（Phase 7 重设计）

    @ViewBuilder
    private func findingsSection(_ pre: PushSession.Preflight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(pre)
            if pre.scanSkippedByKillSwitch {
                scanSkippedBanner
            } else if !pre.hasAnyIssue {
                cleanChecklist
            } else {
                issuesScroller(pre)
            }
        }
    }

    private func sectionHeader(_ pre: PushSession.Preflight) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Copy.Guard.sectionTitle(tone))
                .font(.piloSection)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            if pre.scanSkippedByKillSwitch {
                EmptyView()
            } else if !pre.hasAnyIssue {
                Text(Copy.Guard.sectionSummaryClear(tone))
                    .font(.piloCaption)
                    .foregroundStyle(Color.mintSafe)
            } else {
                if pre.totalCriticalCount > 0 {
                    severityChip(count: pre.totalCriticalCount, severity: .critical)
                }
                if pre.totalWarningCount > 0 {
                    severityChip(count: pre.totalWarningCount, severity: .warning)
                }
            }
        }
    }

    private func severityChip(count: Int, severity: FindingSeverity) -> some View {
        let tint: Color = severity == .critical ? .roseDanger : .amberWarn
        let label: String = severity == .critical ? "高危 \(count)" : "提示 \(count)"
        return Text(label)
            .font(.piloCaption)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
    }

    private var cleanChecklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Copy.Guard.summaryAllClear(tone), id: \.self) { line in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.mintSafe)
                        .font(.system(size: 12))
                    Text(line)
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.mintSafe.opacity(0.10))
        )
    }

    private var scanSkippedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(Color.amberWarn)
            Text(Copy.Scan.killSwitchSkipped(tone))
                .font(.piloCaption)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.amberWarn.opacity(0.15))
        )
    }

    private func issuesScroller(_ pre: PushSession.Preflight) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if pre.totalCriticalCount > 0 {
                    issueGroup(
                        title: Copy.Guard.criticalGroupTitle,
                        severity: .critical,
                        scanFindings: pre.criticalFindings,
                        guardFindings: pre.criticalGuardFindings
                    )
                }
                if pre.totalWarningCount > 0 {
                    issueGroup(
                        title: Copy.Guard.warningGroupTitle,
                        severity: .warning,
                        scanFindings: pre.warningFindings,
                        guardFindings: pre.warningGuardFindings
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 260)
    }

    @ViewBuilder
    private func issueGroup(
        title: String,
        severity: FindingSeverity,
        scanFindings: [ScanFinding],
        guardFindings: [CommitGuardFinding]
    ) -> some View {
        let tint: Color = severity == .critical ? .roseDanger : .amberWarn
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(tint)
                Text(title)
                    .font(.piloCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
            }
            ForEach(scanFindings) { f in
                scanFindingCard(f)
            }
            ForEach(guardFindings) { f in
                guardFindingCard(f)
            }
        }
    }

    // MARK: - 单条卡片

    @ViewBuilder
    private func scanFindingCard(_ finding: ScanFinding) -> some View {
        let tint: Color = finding.severity == .critical ? .roseDanger : .amberWarn
        baseCard(tint: tint) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(tint)
                    .font(.system(size: 13))
                Text(finding.ruleName)
                    .font(.piloSection)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(finding.filePath):\(finding.lineNumber)")
                    .font(.piloMono)
                    .foregroundStyle(Color.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text(finding.lineSnippet)
                .font(.piloMono)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.cloudDivider.opacity(0.4))
                )
            actionRow {
                iconButton("arrow.up.right.square", Copy.Guard.jumpToCodeButton) {
                    revealScanFinding(finding)
                }
                if finding.severity == .warning {
                    iconButton("eye.slash", Copy.Guard.ignoreOnceButton) {
                        appState.ignoreOnce(findingId: finding.id)
                    }
                }
                iconButton("checkmark.shield", Copy.Guard.markSafeButton) {
                    appState.falsePositivePickerTarget = finding
                }
            }
        }
    }

    @ViewBuilder
    private func guardFindingCard(_ finding: CommitGuardFinding) -> some View {
        let tint: Color = finding.severity == .critical ? .roseDanger : .amberWarn
        baseCard(tint: tint) {
            HStack(spacing: 8) {
                Image(systemName: iconForGuardKind(finding.kind))
                    .foregroundStyle(tint)
                    .font(.system(size: 13))
                Text(finding.displayKind)
                    .font(.piloSection)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if let sz = finding.formattedSize {
                    Text(sz)
                        .font(.piloMono)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            Text(finding.filePath)
                .font(.piloMono)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.cloudDivider.opacity(0.4))
                )
            Text(finding.explanation)
                .font(.piloCaption)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            actionRow {
                iconButton("folder", Copy.Guard.showInFinderButton) {
                    revealGuardFinding(finding)
                }
                if case .addToGitignore = finding.suggestion {
                    iconButton("doc.badge.plus", Copy.Guard.addToGitignoreButton) {
                        appState.addToGitignore(for: finding)
                    }
                }
                if case .useLFS = finding.suggestion {
                    iconButton("arrow.up.doc", Copy.Guard.learnLFSButton) {
                        if let url = URL(string: "https://git-lfs.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                if finding.severity == .warning {
                    iconButton("eye.slash", Copy.Guard.ignoreOnceButton) {
                        appState.ignoreOnce(findingId: finding.id)
                    }
                }
            }
        }
    }

    private func iconForGuardKind(_ kind: CommitGuardFinding.Kind) -> String {
        switch kind {
        case .envFile:           return "doc.text.fill"
        case .privateKey:        return "key.horizontal.fill"
        case .publicKey:         return "key"
        case .largeFile:         return "doc.zipper"
        case .oversizeBlocked:   return "exclamationmark.octagon"
        case .buildArtifact:     return "shippingbox"
        case .dsStore:           return "doc.text"
        }
    }

    // MARK: - 通用卡片骨架

    @ViewBuilder
    private func baseCard<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.paperCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func actionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
            Spacer()
        }
        .padding(.top, 2)
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                Text(label)
                    .font(.piloCaption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.cloudDivider.opacity(0.5))
            )
            .foregroundStyle(Color.inkPrimary)
        }
        .buttonStyle(.plain)
    }

    private func revealScanFinding(_ finding: ScanFinding) {
        guard let repoPath = currentRepoPath else { return }
        let fileURL = URL(fileURLWithPath: repoPath).appendingPathComponent(finding.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func revealGuardFinding(_ finding: CommitGuardFinding) {
        guard let repoPath = currentRepoPath else { return }
        let fileURL = URL(fileURLWithPath: repoPath).appendingPathComponent(finding.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private var currentRepoPath: String? {
        appState.pushSession.flatMap { s -> String? in
            if case .preflight(let pre) = s.state { return pre.repoPath }
            return nil
        }
    }

    private func preflightFooter(_ pre: PushSession.Preflight) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Button(Copy.Push.cancelButton(tone), action: onDismiss)
                    .buttonStyle(.piloSecondary)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if pre.hasCritical && !pre.bypassConfirmed {
                    Button {
                        // 不可达；按钮已 disabled
                    } label: {
                        Text(Copy.Guard.pushDisabledByCritical(tone))
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.piloPrimary)
                    .disabled(true)
                } else if pre.bypassConfirmed {
                    Button {
                        Task { await appState.executePush() }
                    } label: {
                        Text(Copy.Scan.pushBypassButton(tone))
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.piloDestructive)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        Task { await appState.executePush() }
                    } label: {
                        Text(Copy.Push.pushButton(tone))
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.piloPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(pre.commits.isEmpty)
                }
            }
            // bypass 降级为安静文字链接，不和主按钮等权重
            if pre.hasCritical && !pre.bypassConfirmed {
                Button {
                    showBypassDialog = true
                } label: {
                    Text(Copy.Guard.pushBypassLink(tone))
                        .font(.piloCaption)
                        .foregroundStyle(Color.inkTertiary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
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
            PiloMascot(mood: .happy, size: 96, breathing: true)
            Text(Copy.Push.successTitle(tone))
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            Text(Copy.Push.successSubtitle(tone, count: report.commitCount))
                .font(.piloBody)
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Button(Copy.Push.doneButton, action: onDismiss)
                .buttonStyle(.piloPrimary)
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
                .buttonStyle(.piloSecondary)
                Button(Copy.Push.openTerminalButton) {
                    openTerminal(at: appState.repositories.first(where: { $0.id == report.repoId })?.path)
                }
                .buttonStyle(.piloSecondary)
                Spacer()
                Button(Copy.Push.closeButton, action: onDismiss)
                    .buttonStyle(.piloPrimary)
                    .keyboardShortcut(.defaultAction)
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
