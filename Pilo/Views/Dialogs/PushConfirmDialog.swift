import SwiftUI
import AppKit

/// 推送确认 sheet。三态：preflight / running / completed。
/// 安全检查区域 Phase 6 启用，当前显示占位。
struct PushConfirmDialog: View {

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lang: Language { appState.language }

    @Binding var session: PushSession?
    let onDismiss: () -> Void

    @State private var showBypassDialog = false
    /// History 脱钩时点"覆盖远程历史"会弹出二次确认 popover
    @State private var showForcePushConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            switch session?.state {
            case .loading(let l):
                loadingView(repoName: l.repoName)
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
                Text(Copy.Push.preflightTitle(tone, lang))
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            Text(Copy.Push.preflightSubtitle(tone, lang, count: pre.commits.count))
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
                Button(Copy.Push.cancelButton(tone, lang), action: onDismiss)
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
                        Text(Copy.Scan.pushBypassButton)
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.piloDestructive)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        Task { await appState.executePush() }
                    } label: {
                        Text(Copy.Push.pushButton(tone, lang))
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
            Text(Copy.Push.runningTitle(tone, lang, remote: remote))
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
        .padding(24)
    }

    /// Loading 态：beginPushSession 跑 diff / secret scan / blob size 等 heavy 操作期间立刻弹出，
    /// 让 sheet 不再等几秒空白。
    private func loadingView(repoName: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            PiloMascot(mood: .alert, size: 80, breathing: !reduceMotion)
            Text(Copy.Push.loadingTitle(tone, lang))
                .font(.piloTitle)
                .foregroundStyle(Color.inkPrimary)
            Text(Copy.Push.loadingSubtitle(lang, repoName: repoName))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
            ProgressView()
                .controlSize(.small)
                .tint(Color.piloGoldDark)
                .padding(.top, 4)
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
        VStack(spacing: PiloSpacing.l) {
            Spacer(minLength: PiloSpacing.s)

            // P 蜡封作主视觉（Pilo 官方封缄）+ Happy 鸽子作辅助
            // "已寄出 = 信件已盖章封好"的语义；P 蜡封跟品牌 brand 直接连接
            ZStack(alignment: .bottomTrailing) {
                Image("WaxSealPilo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-6))
                    .shadow(color: Color.stampRed.opacity(0.2), radius: 3, y: 2)

                // Mascot 缩小到右下角作"完成"情感辅助
                PiloMascot(mood: .happy, size: 44, breathing: true)
                    .offset(x: 18, y: 6)
            }

            // 衬线大标题 + 斜体副标题
            VStack(spacing: PiloSpacing.xs) {
                Text(Copy.Push.successTitle(tone, lang))
                    .font(.piloSerifHero)
                    .tracking(1.0)
                    .foregroundStyle(Color.inkPrimary)
                Text(lang == .zh ? "所有小信都安全到家了" : "All your letters arrived safely")
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkSecondary)
            }

            // 3 列 stats grid
            statsGrid(report)
                .padding(.vertical, PiloSpacing.s)

            // 「已寄出 · YYYY.MM.DD」绿色邮戳
            RotatedStamp(
                text: stampText,
                tint: .stampMint,
                rotation: -3,
                dashStyle: false
            )

            Spacer(minLength: PiloSpacing.s)

            Button(Copy.Push.doneButton, action: onDismiss)
                .buttonStyle(.piloPrimary)
                .keyboardShortcut(.defaultAction)
        }
        .padding(PiloSpacing.xl)
    }

    private func statsGrid(_ report: PushReport) -> some View {
        HStack(spacing: PiloSpacing.s) {
            statBox(num: "1", label: lang == .zh ? "个仓库" : "repo")
            statBox(num: "\(report.commitCount)", label: lang == .zh ? "个 commit" : "commits")
            statBox(num: "✨", label: lang == .zh ? "送达" : "delivered")
        }
        .frame(maxWidth: 340)
    }

    private func statBox(num: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(num)
                .font(.piloSerifHero)
                .foregroundStyle(Color.piloBlue)
            Text(label)
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PiloSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaperBorder.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.piloPaperBorder, lineWidth: 0.5)
                )
        )
    }

    private var stampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = lang == .zh ? "yyyy.MM.dd" : "MMM d, yyyy"
        let date = formatter.string(from: Date())
        return lang == .zh ? "已寄出 · \(date)" : "DELIVERED · \(date)"
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

                // History 脱钩时显示 force push 按钮（金棕色警示，跟普通按钮区分）
                if report.outcome.isHistoryDiverged {
                    Button(Copy.Push.forcePushButton(lang)) {
                        showForcePushConfirm = true
                    }
                    .buttonStyle(.piloSecondary)
                    .foregroundStyle(Color.piloGoldDark)
                    .popover(isPresented: $showForcePushConfirm, arrowEdge: .top) {
                        forcePushConfirmPopover()
                    }
                }

                Button(Copy.Push.closeButton, action: onDismiss)
                    .buttonStyle(.piloPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    /// "覆盖远程历史"按钮的二次确认 popover —— 强制用户停一下、读完风险再点确认。
    private func forcePushConfirmPopover() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.amberWarn)
                Text(Copy.Push.forcePushConfirmTitle(lang))
                    .font(.piloTitle)
                    .foregroundStyle(Color.inkPrimary)
            }
            Text(Copy.Push.forcePushConfirmBody(lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320, alignment: .leading)
            HStack(spacing: 10) {
                Spacer()
                Button(Copy.Push.forcePushConfirmNo(lang)) {
                    showForcePushConfirm = false
                }
                .buttonStyle(.piloSecondary)
                .keyboardShortcut(.cancelAction)

                Button(Copy.Push.forcePushConfirmYes(lang)) {
                    showForcePushConfirm = false
                    Task { await appState.forcePushCurrentSession() }
                }
                .buttonStyle(.piloPrimary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(Color.piloPaper)
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
/// Push running 状态动画：PAR AVION 航空邮件飞机 + 飞行轨迹。
/// 取代了原来的 FlyingPiloAnimation（鸽子飞翔）—— 飞机更直接对应"信件正在投递路径"
/// 的视觉传统，PAR AVION 旗帜本身就是国际邮件标识。Mascot 鸽子保留给品牌情感时刻。
private struct FlyingPiloAnimation: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Image("PostalPlane")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            // 飞机往右前方"前进"的视觉：水平 + 垂直微微抖动
            .offset(
                x: 6 * sin(phase * .pi * 2),
                y: -8 * sin(phase * .pi * 2 + .pi / 3)
            )
            // 飞机略微歪向飞行方向（-3° 到 +3° 来回）
            .rotationEffect(.degrees(Double(sin(phase * .pi * 4) * 3)))
            .shadow(color: Color.piloBlueDark.opacity(0.15), radius: 4, y: 4)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    phase += 0.012
                    if phase > 1 { phase -= 1 }
                }
            }
    }
}
