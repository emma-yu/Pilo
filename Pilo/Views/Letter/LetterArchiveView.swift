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
            if appState.letterArchive.letters.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(appState.letterArchive.letters) { letter in
                            letterRow(letter)
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
