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
            // Header —— 标题在左，PostalDial 邮戳水印在右上角
            // 跟真实邮件传统一致：邮戳盖在信件右上（邮票位置），表示"已被邮局处理"
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Letter.letterHeader(lang))
                        .font(.custom("Songti SC", size: 28).weight(.medium))
                        .foregroundStyle(Color.inkPrimary)
                    OrnamentDivider(width: 180)
                }
                Spacer()
                // PostalDial 水印效果：opacity 0.72 + multiply 让它"嵌进信纸"，
                // 不抢标题，-8° 倾斜模拟"盖印瞬间"的物理感
                Image("PostalDial")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-8))
                    .opacity(0.72)
                    .blendMode(.multiply)
                    .offset(y: -8)
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

            // 今日邮局合作社 —— AI 工具协作日志（仅当今天检测到活动）
            if let companions = letter.aiCompanions, !companions.isEmpty {
                aiCompanionsSection(companions)
            }

            // 工作时段已删 —— 容易引发焦虑且非用户关心的信息

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
            VStack(alignment: .leading, spacing: 4) {
                ForEach(summary.commits, id: \.hash) { c in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        // bullet —— 表示"做了一件事"
                        Text("·")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark.opacity(0.6))
                            .frame(width: 8)
                        // subject 主显，占 80% 视觉
                        Text(c.subject)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        // hash 右后置，灰色小字 mono —— 给技术用户的 reference
                        Text(c.hash)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                if summary.moreCount > 0 {
                    Text(Copy.Letter.moreCommits(summary.moreCount, lang))
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, 18)
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
        // 简化：只 repo 名 + N 个未提交，不展开文件路径（用户说太啰嗦）
        HStack(spacing: 6) {
            Text("·").foregroundStyle(Color.inkTertiary)
            Text(d.repoName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
            Text(Copy.Letter.draftCount(d.uncommittedCount, lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkSecondary)
        }
    }

    /// 今日邮局合作社 —— 跨 AI 工具的活跃度摘要 section
    /// 风格镜像 draftSection（icon + Songti 标题 + 缩进列表）
    private func aiCompanionsSection(_ companions: [AICompanionSummary]) -> some View {
        let total = companions.reduce(0) { $0 + $1.activityCount }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.piloGoldDark)
                Text(Copy.Letter.aiCompanionsHeader(lang))
                    .font(.custom("Songti SC", size: 16))
                    .foregroundStyle(Color.inkPrimary)
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(companions, id: \.tool) { c in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: c.tool.symbol)
                            .font(.system(size: 11))
                            .foregroundStyle(c.tool.tintColor)
                            .frame(width: 14)
                        Text(c.tool.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                        Text("· " + Copy.Letter.aiCompanionUnit(count: c.activityCount, tool: c.tool, lang))
                            .font(.piloSerifCaption)
                            .italic()
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                if companions.count > 1 {
                    Text(Copy.Letter.aiCompanionsFooter(totalCount: total, toolCount: companions.count, lang))
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.top, 2)
                }
            }
            .padding(.leading, 22)
        }
        .padding(.top, 8)
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
