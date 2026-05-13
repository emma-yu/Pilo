import SwiftUI

/// Resume Work 卡片：详情面板顶部"欢迎回来"信件。
///
/// 显示规则：
///   - 至少要有"未提交文件"或"最近 commit"之一才显示（避免完全空卡）
///   - lastViewedDate 为 nil → 标题改成"初次见面"
///   - 跟邮局美学一致：cream paper bg + 金色装饰线 + Songti SC 衬线 + 信纸卡片列表
struct ResumeWorkCard: View {

    let repo: Repository
    let uncommittedFiles: [UncommittedFile]
    let recentCommits: [CommitSummary]

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    private var lang: Language { appState.language }

    /// 是否应该显示。caller 也可以读这个判断；为 false 时返回 EmptyView。
    var shouldShow: Bool {
        !uncommittedFiles.isEmpty || !recentCommits.isEmpty
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 0) {
                header
                divider
                if !uncommittedFiles.isEmpty {
                    draftsSection
                }
                if !uncommittedFiles.isEmpty && !recentCommits.isEmpty {
                    Spacer().frame(height: PiloSpacing.m)
                }
                if !recentCommits.isEmpty {
                    recentSection
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
        let firstTime = repo.lastViewedDate == nil
        let days = repo.lastViewedDate.map {
            max(0, Int(Date().timeIntervalSince($0) / 86400))
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.piloGold)
                Text(Copy.Resume.title(firstTime: firstTime, tone, lang))
                    .font(.piloSerifTitle)
                    .foregroundStyle(Color.inkPrimary)
            }
            let sub = Copy.Resume.subtitle(
                uncommittedCount: repo.uncommittedCount,
                pendingPushCount: repo.aheadCount,
                daysSinceViewed: firstTime ? nil : days,
                branch: repo.currentBranch,
                tone,
                lang
            )
            if !sub.isEmpty {
                Text(sub)
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var divider: some View {
        OrnamentDivider(width: 180)
            .padding(.vertical, 10)
    }

    // MARK: - 草稿

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Copy.Resume.draftsLabel(count: uncommittedFiles.count, lang))
                .font(.piloSerifLabel)
                .foregroundStyle(Color.piloGoldDark)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(uncommittedFiles.prefix(6)) { file in
                    draftRow(file)
                }
                if uncommittedFiles.count > 6 {
                    let more = uncommittedFiles.count - 6
                    Text(lang == .zh ? "…还有 \(more) 个" : "…and \(more) more")
                        .font(.piloSerifCaption)
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, 22)
                }
            }
        }
    }

    private func draftRow(_ file: UncommittedFile) -> some View {
        HStack(spacing: 8) {
            Text(Copy.Resume.statusBadge(file.status))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor(file.status))
                .frame(width: 14)
            Text(file.path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private func statusColor(_ status: UncommittedFile.Status) -> Color {
        switch status {
        case .modified, .renamed, .copied:   return .amberWarn
        case .added, .untracked:             return .mintSafe
        case .deleted:                       return .roseDanger
        case .conflicted:                    return .roseDanger
        case .other:                         return .inkTertiary
        }
    }

    // MARK: - 最近寄出

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Copy.Resume.recentSentLabel(lang))
                .font(.piloSerifLabel)
                .foregroundStyle(Color.piloGoldDark)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(recentCommits.prefix(3)) { commit in
                    recentRow(commit)
                }
            }
        }
    }

    private func recentRow(_ commit: CommitSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(commit.hash)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.piloGoldDark)
                .frame(width: 60, alignment: .leading)
            Text(commit.subject)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(RepoCard.relativeFormatter.localizedString(for: commit.date, relativeTo: Date()))
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkTertiary)
                .frame(minWidth: 70, alignment: .trailing)
        }
    }
}
