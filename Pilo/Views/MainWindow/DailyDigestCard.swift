import SwiftUI

/// S2 跨 Repo 工作日报：主面板顶部 cream paper 卡片。
/// 默认展开；用户可手动收起，状态在 session 内保留。
/// 跟 ResumeWorkCard 视觉一致：Songti italic 标题 + 金色 OrnamentDivider + 信纸卡列表
struct DailyDigestCard: View {

    let digest: DailyDigest

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    @State private var isExpanded: Bool = true

    private var lang: Language { appState.language }

    /// 没任何活动 → caller 应判断 isEmpty 后决定显示与否
    var shouldShow: Bool { !digest.isEmpty }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 0) {
                header
                if isExpanded {
                    OrnamentDivider(width: 180)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    sections
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.piloPaperBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGold)
            Text(Copy.DailyDigest.cardTitle(lang, dateString: Self.dateFormatter.string(from: digest.date)))
                .font(.piloSerifTitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? Copy.DailyDigest.collapseLabel(lang) : Copy.DailyDigest.expandLabel(lang))
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sections: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !digest.pushedRepos.isEmpty {
                sectionGroup(
                    label: Copy.DailyDigest.sectionPushed(count: digest.pushedRepos.count, lang),
                    rows: digest.pushedRepos,
                    dot: Color.mintSafe,
                    showCommits: true
                )
            }
            if !digest.modifiedNotPushed.isEmpty {
                sectionGroup(
                    label: Copy.DailyDigest.sectionDrafting(count: digest.modifiedNotPushed.count, lang),
                    rows: digest.modifiedNotPushed,
                    dot: Color.amberWarn,
                    showCommits: true
                )
            }
            if !digest.visitedOnly.isEmpty {
                sectionGroup(
                    label: Copy.DailyDigest.sectionVisited(count: digest.visitedOnly.count, lang),
                    rows: digest.visitedOnly,
                    dot: Color.inkTertiary,
                    showCommits: false
                )
            }
        }
    }

    private func sectionGroup(
        label: String,
        rows: [DailyDigest.DigestRow],
        dot: Color,
        showCommits: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.piloSerifLabel)
                .foregroundStyle(Color.piloGoldDark)
            VStack(spacing: 2) {
                ForEach(rows) { row in
                    digestRow(row, dot: dot, showCommits: showCommits)
                }
            }
        }
    }

    private func digestRow(_ row: DailyDigest.DigestRow, dot: Color, showCommits: Bool) -> some View {
        Button {
            appState.selectRepo(row.repoId)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
                Text(row.repoName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                if showCommits {
                    Text(Copy.DailyDigest.commitCountSuffix(row.commitsToday, lang))
                        .font(.piloSerifCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: 0)
                Text(Self.timeFormatter.string(from: row.lastActivityToday))
                    .font(.piloSerifCaption)
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloGold.opacity(0.08), cornerRadius: 6)
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
