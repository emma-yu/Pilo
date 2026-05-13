import SwiftUI

/// 邮票本全集 sheet —— 浏览、排序、编辑全部邮票。
struct PromptStampArchiveSheet: View {

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    @State private var sortKey: SortKey = .recent

    enum SortKey: String, CaseIterable {
        case useCount, recent, name

        func label(_ lang: Language) -> String {
            switch self {
            case .useCount: return Copy.Stamps.sortByUseCount(lang)
            case .recent:   return Copy.Stamps.sortByRecent(lang)
            case .name:     return Copy.Stamps.sortByName(lang)
            }
        }
    }

    private var sortedStamps: [PromptStamp] {
        let s = appState.promptStampArchive.stamps
        switch sortKey {
        case .useCount:
            return s.sorted { $0.useCount > $1.useCount }
        case .recent:
            return s.sorted { (a, b) in
                (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
            }
        case .name:
            return s.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            if appState.promptStampArchive.stamps.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(sortedStamps) { stamp in
                            row(stamp)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .frame(width: 560, height: 640)
        .background(Color.piloPaper.opacity(0.95))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            VStack(alignment: .leading, spacing: 0) {
                Text(Copy.Stamps.archiveTitle(lang))
                    .font(.piloSerifTitle)
                    .foregroundStyle(Color.inkPrimary)
                Text(Copy.Stamps.archiveSubtitle(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()

            // 排序 picker
            Picker("", selection: $sortKey) {
                ForEach(SortKey.allCases, id: \.self) { key in
                    Text(key.label(lang)).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            // + 新建按钮
            Button(action: {
                appState.closeStampArchive()
                appState.openStampEditor()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(6)
                    .background(Circle().fill(Color.piloGold.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(Copy.Stamps.addNewHint(lang))

            // 关闭
            Button(action: { appState.closeStampArchive() }) {
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "envelope.badge")
                .font(.system(size: 44))
                .foregroundStyle(Color.piloGoldDark.opacity(0.4))
            Text(Copy.Stamps.emptyTitle(lang))
                .font(.piloSerifSubtitle)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            Button(action: {
                appState.closeStampArchive()
                appState.openStampEditor()
            }) {
                Text("+ " + Copy.Stamps.emptyHint(lang))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.piloGold.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.piloGold.opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    private func row(_ stamp: PromptStamp) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PromptStampChip(stamp: stamp, size: .large)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(stamp.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    if stamp.pinned {
                        Text(Copy.Stamps.pinnedBadge(lang))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(Color.piloGoldDark.opacity(0.5), lineWidth: 0.6)
                            )
                    }
                    Spacer()
                    Text(Copy.Stamps.useCountLabel(stamp.useCount, lang))
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                }
                Text(stamp.body)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button(action: { appState.pasteStamp(stamp) }) {
                        Label(Copy.Stamps.menuCopy(lang), systemImage: "doc.on.doc")
                            .font(.piloSerifCaption)
                            .foregroundStyle(Color.piloBlueDark)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        appState.closeStampArchive()
                        appState.openStampEditor(stamp)
                    }) {
                        Label(Copy.Stamps.menuEdit(lang), systemImage: "pencil")
                            .font(.piloSerifCaption)
                            .foregroundStyle(Color.piloGoldDark)
                    }
                    .buttonStyle(.plain)

                    Button(action: { appState.togglePinStamp(stamp.id) }) {
                        Label(
                            stamp.pinned ? Copy.Stamps.menuUnpin(lang) : Copy.Stamps.menuPin(lang),
                            systemImage: stamp.pinned ? "pin.slash" : "pin"
                        )
                        .font(.piloSerifCaption)
                        .foregroundStyle(Color.piloGoldDark)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { appState.deletePromptStamp(stamp.id) }) {
                        Label(Copy.Stamps.menuDelete(lang), systemImage: "trash")
                            .font(.piloSerifCaption)
                            .foregroundStyle(Color.roseDanger)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.piloPaper.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.piloPaperBorder, lineWidth: 0.5)
        )
    }
}
