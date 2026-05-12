import SwiftUI

/// 信箱 view —— 列出过往所有信件，按日期倒序。
/// 点单封 → AppState.openLetter(letter) 切到 reader sheet。
struct LetterArchiveView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            // 信箱混合：DailyLetter（每日工作总结）+ ReleaseLetter（版本通告）
            // 通过 InboxItem 合并 + 按 sortDate 倒序排
            let items = appState.inboxItems
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(items) { item in
                            switch item {
                            case .daily(let l):
                                letterRow(l)
                            case .release(let r):
                                releaseRow(r)
                            case .updateAvailable(let u):
                                updateRow(u)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .frame(width: 520, height: 600)
        .background(Color.piloPaper.opacity(0.95))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            VStack(alignment: .leading, spacing: 0) {
                Text(Copy.Letter.archiveTitle(lang))
                    .font(.piloSerifTitle)
                    .foregroundStyle(Color.inkPrimary)
                Text(Copy.Letter.archiveSubtitle(tone, lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Button(action: { appState.isArchiveSheetOpen = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(6)
                    .background(Circle().fill(Color.cloudDivider.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(Color.piloGoldDark.opacity(0.4))
            Text(Copy.Letter.archiveEmpty(tone, lang))
                .font(.piloSerifSubtitle)
                .italic()
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func letterRow(_ letter: DailyLetter) -> some View {
        Button {
            appState.openLetter(letter)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // 未读 / 已读 dot
                Circle()
                    .fill(letter.isUnread ? Color.stampRed : Color.inkTertiary.opacity(0.4))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(Self.dateFormatter.string(from: letter.date))
                            .font(.system(size: 14, weight: letter.isUnread ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(Self.relativeFormatter.localizedString(for: letter.date, relativeTo: Date()))
                            .font(.piloSerifCaption)
                            .italic()
                            .foregroundStyle(Color.inkTertiary)
                    }
                    summary(for: letter)
                        .font(.piloSerifCaption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloGold.opacity(0.08), cornerRadius: 7)
    }

    /// 版本通告行 —— 跟 DailyLetter 行平级排，视觉差异化：
    ///   - stampRed 圆点（红蜡封感）替代普通已读/未读 dot
    ///   - `scroll.fill` 邮局通告 icon
    ///   - 标题 "v0.4 · AI 时代的小邮局" Songti 衬线
    private func releaseRow(_ letter: ReleaseLetter) -> some View {
        Button {
            appState.openReleaseLetter(letter)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // 通告专属：scroll icon + stampRed 红蜡封感
                Image(systemName: "scroll.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(letter.isUnread ? Color.stampRed : Color.stampRed.opacity(0.45))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(Copy.Letter.releaseRowHeader(version: letter.version, lang))
                            .font(.custom("Songti SC", size: 14).weight(letter.isUnread ? .semibold : .medium))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(Self.relativeFormatter.localizedString(for: letter.releaseDate, relativeTo: Date()))
                            .font(.piloSerifCaption)
                            .italic()
                            .foregroundStyle(Color.inkTertiary)
                    }
                    Text(letter.title)
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                // 通告底色比 daily 行多一层 piloAccent（心粉）淡淡感，视觉分层
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(letter.isUnread ? Color.piloAccent.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloGold.opacity(0.08), cornerRadius: 7)
    }

    /// 「新版本已发车」行 —— 视觉最显眼（蓝色 piloBlue 引导动作）
    ///   - paperplane icon（已发车的意象）
    ///   - 蓝色 bg 淡淡填充 + piloBlue 描边强调"action needed"
    ///   - 标题 "v0.5 · 新版已发车"
    private func updateRow(_ letter: UpdateAvailableLetter) -> some View {
        Button {
            appState.openUpdateLetter(letter)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(letter.isUnread ? Color.piloBlue : Color.piloBlue.opacity(0.55))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(Copy.Letter.updateRowHeader(version: letter.version, lang))
                            .font(.custom("Songti SC", size: 14).weight(letter.isUnread ? .semibold : .medium))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(Self.relativeFormatter.localizedString(for: letter.detectedAt, relativeTo: Date()))
                            .font(.piloSerifCaption)
                            .italic()
                            .foregroundStyle(Color.inkTertiary)
                    }
                    Text(letter.title)
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(letter.isUnread ? Color.piloBlue.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(letter.isUnread ? Color.piloBlue.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverable(highlight: Color.piloBlue.opacity(0.08), cornerRadius: 7)
    }

    private func summary(for letter: DailyLetter) -> Text {
        if letter.totalCommits == 0 && letter.draftRepos.isEmpty {
            return Text(Copy.Letter.emptyLetterBody(tone, lang))
        }
        return Text(
            Copy.Letter.totalLine(
                commits: letter.totalCommits,
                repos: letter.activeRepoCount,
                lang
            )
        )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
