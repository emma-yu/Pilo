import SwiftUI

/// 邮票本全集 sheet —— 浏览、排序、编辑全部邮票。
struct PromptStampArchiveSheet: View {

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    @State private var sortKey: SortKey = .recent
    @State private var searchText: String = ""
    @State private var isSortMenuOpen: Bool = false

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

    /// 按 sort + search 双过滤后的 stamps
    private var visibleStamps: [PromptStamp] {
        let s = appState.promptStampArchive.stamps
        let sorted: [PromptStamp]
        switch sortKey {
        case .useCount:
            sorted = s.sorted { $0.useCount > $1.useCount }
        case .recent:
            sorted = s.sorted { (a, b) in
                (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
            }
        case .name:
            sorted = s.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.body.localizedCaseInsensitiveContains(q)
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
                searchBar
                if visibleStamps.isEmpty {
                    noMatchState
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(visibleStamps) { stamp in
                                row(stamp)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    tipFooter
                }
            }
        }
        .frame(width: 560, height: 640)
        .background(Color.piloPaper.opacity(0.95))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkTertiary)
            TextField(Copy.Stamps.searchPlaceholder(lang), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkTertiary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(Copy.Stamps.searchClear(lang))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.piloPaper.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.piloGold.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Tip footer
    //
    // 安静提示——告诉用户 sidebar 邮票本可以右键"钉到首位 ✦"。位置在 ScrollView
    // 下方，永远可见但不抢戏。设计要点：极淡 inkTertiary 灰 + Songti italic +
    // 小金 ✦ 跟 row 上的 badge 视觉呼应；无背景无边框，纯文字漂在底部。
    private var tipFooter: some View {
        HStack(spacing: 5) {
            Text("✦")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.piloGoldDark.opacity(0.6))
            Text(Copy.Stamps.archiveTip(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 9)
        .padding(.horizontal, 16)
    }

    private var noMatchState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.piloGoldDark.opacity(0.45))
            Text(Copy.Stamps.searchNoMatch(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sort picker（Pilo 风 dropdown，替代系统 .pickerStyle(.menu)）
    //
    // Trigger = cream paper button + 当前 sort label + 小 chevron；
    // 点击弹 popover 三项选择，hover gold tint，selected 项加 ✓ icon。

    private var sortPicker: some View {
        Button(action: { isSortMenuOpen.toggle() }) {
            HStack(spacing: 5) {
                Text(sortKey.label(lang))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.piloGoldDark.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.piloGold.opacity(0.4), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(lang == .zh ? "排序方式" : "Sort by")
        .popover(isPresented: $isSortMenuOpen, arrowEdge: .bottom) {
            VStack(spacing: 1) {
                ForEach(SortKey.allCases, id: \.self) { key in
                    sortRow(key)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.piloPaper.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func sortRow(_ key: SortKey) -> some View {
        let isSelected = sortKey == key
        Button(action: {
            sortKey = key
            isSortMenuOpen = false
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.piloGoldDark : Color.piloGoldDark.opacity(0.25))
                    .frame(width: 14, alignment: .center)
                Text(key.label(lang))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.piloGold.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

            // 排序 picker —— Pilo 风（cream paper + gold border + 衬线 label）
            sortPicker

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
                    if stamp.topPinned {
                        Text("✦")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(Color.piloGoldDark.opacity(0.5), lineWidth: 0.6)
                            )
                            .help(Copy.Stamps.topPinnedBadgeTooltip(lang))
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

                    Button(action: { appState.toggleStampTopPinned(stamp.id) }) {
                        Label(
                            stamp.topPinned ? Copy.Stamps.unpinFromTop(lang) : Copy.Stamps.pinToTop(lang),
                            systemImage: stamp.topPinned ? "star.slash" : "star.fill"
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
