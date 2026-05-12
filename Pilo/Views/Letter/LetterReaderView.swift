import SwiftUI

/// 每日信件阅读 view —— 沉浸式信纸样式。
/// cream paper + Songti 衬线 + 金线 + 称呼 + 落款。
/// 用户读完关闭 → AppState 自动标记为已读。
struct LetterReaderView: View {

    let letter: DailyLetter

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            ScrollView {
                content
                    .padding(.horizontal, 48)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 640, height: 720)
        .background(Color.piloPaper.opacity(0.95))
        .onAppear {
            appState.markLetterRead(letter)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(Self.dateFormatter.string(from: letter.date))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkPrimary)
            if letter.isUnread {
                Text(Copy.Letter.unreadBadge(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.stampRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.stampRed.opacity(0.5), lineWidth: 0.5)
                    )
            }
            Spacer()
            Button(action: { appState.closeReadingLetter() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(6)
                    .background(Circle().fill(Color.cloudDivider.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Letter Content (信纸排版)

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(Copy.Letter.letterHeader(lang))
                    .font(.custom("Songti SC", size: 28).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                OrnamentDivider(width: 180)
            }
            .padding(.bottom, 8)

            // 称呼 —— dynamic name fallback "朋友"
            Text(Copy.Letter.greeting(name: letter.addressee ?? appState.userDisplayName, lang))
                .font(.custom("Songti SC", size: 17))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 4)

            // 开场白
            if !letter.repoSummaries.isEmpty {
                Text(Copy.Letter.openingLine(lang))
                    .font(.custom("Songti SC", size: 16))
                    .foregroundStyle(Color.inkPrimary)
            }

            // Each active repo
            VStack(alignment: .leading, spacing: 14) {
                ForEach(letter.repoSummaries, id: \.repoName) { summary in
                    repoSection(summary)
                }
            }

            // 草稿区
            if !letter.draftRepos.isEmpty {
                draftSection
            }

            // 工作时段（仅 totalCommits > 0 时显示）
            if let span = letter.workSpan {
                workSpanLine(span)
            }

            // 总结线
            if letter.totalCommits > 0 || letter.activeRepoCount > 0 {
                totalLine
            }

            // 落款
            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Letter.closingLine(tone, lang))
                    .font(.custom("Songti SC", size: 16))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 12)
                Text(Copy.Letter.signature(lang))
                    .font(.custom("Songti SC", size: 22).italic())
                    .foregroundStyle(Color.piloGoldDark)
            }
        }
    }

    private func repoSection(_ summary: DailyLetter.RepoSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(summary.pushed ? Color.mintSafe : Color.amberWarn)
                    .frame(width: 7, height: 7)
                Text("· " + summary.repoName)
                    .font(.custom("Songti SC", size: 17).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                Text(metaLine(summary))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.piloGoldDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(summary.commits, id: \.hash) { c in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(c.hash)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.piloGoldDark.opacity(0.7))
                            .frame(width: 56, alignment: .leading)
                        Text(c.subject)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(2)
                    }
                }
                if summary.moreCount > 0 {
                    Text(Copy.Letter.moreCommits(summary.moreCount, lang))
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, 64)
                }
            }
            .padding(.leading, 20)
        }
    }

    private func metaLine(_ summary: DailyLetter.RepoSummary) -> String {
        let countLabel = "\(summary.commitCount) commit" + (summary.commitCount == 1 ? "" : "s")
        let pushLabel = summary.pushed
            ? Copy.Letter.remoteLabel(remote: summary.remote ?? "origin", lang)
            : Copy.Letter.notPushedLabel(lang)
        // +/- 行数（仅当 stat 拿到时）
        if summary.linesAdded > 0 || summary.linesRemoved > 0 {
            let lineChange = Copy.Letter.lineChangeBadge(
                added: summary.linesAdded,
                removed: summary.linesRemoved
            )
            return "[\(countLabel) · \(lineChange) · \(pushLabel)]"
        }
        return "[\(countLabel) · \(pushLabel)]"
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.piloGoldDark)
                Text(Copy.Letter.draftsHeader(lang))
                    .font(.custom("Songti SC", size: 16))
                    .foregroundStyle(Color.inkPrimary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(letter.draftRepos, id: \.repoName) { d in
                    draftRepoBlock(d)
                }
            }
            .padding(.leading, 22)
        }
        .padding(.top, 8)
    }

    private func draftRepoBlock(_ d: DailyLetter.DraftSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("·").foregroundStyle(Color.inkTertiary)
                Text(d.repoName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Text(Copy.Letter.draftCount(d.uncommittedCount, lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }
            if !d.topFiles.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(d.topFiles, id: \.self) { path in
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    let more = d.uncommittedCount - d.topFiles.count
                    if more > 0 {
                        Text(Copy.Letter.draftFilesMore(count: more, lang))
                            .font(.piloSerifCaption)
                            .italic()
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                .padding(.leading, 14)
            }
        }
    }

    private func workSpanLine(_ span: DailyLetter.WorkSpan) -> some View {
        HStack {
            Spacer()
            Text(Copy.Letter.workSpanLine(
                first: span.firstCommit,
                last: span.lastCommit,
                hours: span.hours,
                lang
            ))
            .font(.piloSerifCaption)
            .italic()
            .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .padding(.top, 6)
    }

    private var totalLine: some View {
        HStack {
            Spacer()
            HStack(spacing: 10) {
                Text("✿").foregroundStyle(Color.piloGoldDark.opacity(0.6))
                Text(Copy.Letter.totalLine(
                    commits: letter.totalCommits,
                    repos: letter.activeRepoCount,
                    lang
                ))
                .font(.piloSerifSubtitle)
                .italic()
                .foregroundStyle(Color.inkSecondary)
                Text("✿").foregroundStyle(Color.piloGoldDark.opacity(0.6))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Format

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd EEE"
        return f
    }()
}
