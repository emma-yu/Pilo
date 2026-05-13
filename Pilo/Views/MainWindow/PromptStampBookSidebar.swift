import SwiftUI

/// Sidebar 底部「邮票本」widget。
///
/// **视觉**：双层结构 ——
///   1. 浮动 capsule toolbar（独立矩形，cream + gold border + soft shadow）
///      上面 `+ 新建` 和 `archive` 两个按钮
///   2. 便签纸 card（cream + gold border + shadow + 14pt radius）
///      内部 3-column grid 展示邮票（chip + 1-line caption）
///
/// **三态**：
///   - empty（无邮票）：card 内显示 envelope icon + 「+ 盖第一张」
///   - few（≤5 张钉住）：grid 列出钉住邮票
///   - many（钉得多 或 archive 里有未钉的）：grid + 「+N」overflow 格点击进 archive
///
/// **自适应高度**：钉得少 sidebar 不被挤；钉得多 grid 展开。
struct PromptStampBookSidebar: View {

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: 8) {
            toolbarCapsule
            stickyNoteCard
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Floating toolbar capsule（上方独立矩形）

    private var toolbarCapsule: some View {
        HStack(spacing: 14) {
            // + 新建邮票
            Button(action: { appState.openStampEditor() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.piloGoldDark)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Copy.Stamps.addNewHint(lang))

            // ⌀ 分隔点
            Circle()
                .fill(Color.piloGold.opacity(0.3))
                .frame(width: 2, height: 2)

            // 📕 archive
            Button(action: { appState.openStampArchive() }) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        appState.totalStampCount == 0
                            ? Color.piloGoldDark.opacity(0.35)
                            : Color.piloGoldDark
                    )
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(appState.totalStampCount == 0)
            .help(Copy.Stamps.allHint(lang))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.piloPaper.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.piloGold.opacity(0.5), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    // MARK: - Sticky note card（下方便签纸）

    private var stickyNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 内部小标题
            HStack(spacing: 4) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.piloGold.opacity(0), Color.piloGold.opacity(0.4)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                Text(Copy.Stamps.sectionTitle(lang))
                    .font(.piloSerifLabel)
                    .foregroundStyle(Color.piloGoldDark)
                    .tracking(1.2)
                    .fixedSize()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.piloGold.opacity(0.4), Color.piloGold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
            }
            .padding(.top, 2)

            if appState.totalStampCount == 0 {
                emptyState
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            } else if appState.sidebarStamps.isEmpty {
                // 有邮票但都没钉
                noPinnedHint
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            } else {
                stampsGrid
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 230)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.piloPaper.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 26))
                .foregroundStyle(Color.piloGoldDark.opacity(0.45))
            Text(Copy.Stamps.emptyTitle(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            Button(action: { appState.openStampEditor() }) {
                Text("+ " + Copy.Stamps.emptyHint(lang))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.piloGold.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.piloGold.opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var noPinnedHint: some View {
        Button(action: { appState.openStampArchive() }) {
            Text(lang == .zh ? "去钉几张到 sidebar →" : "Pin some to sidebar →")
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stamps grid

    private var stampsGrid: some View {
        // 3 列 grid，矩形 illustration 邮票 + 1 行 caption
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .center),
            count: 3
        )
        return LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(appState.sidebarStamps) { stamp in
                StampGridCell(stamp: stamp, lang: lang)
            }
            if appState.sidebarOverflowCount > 0 {
                overflowCell
            }
        }
    }

    private var overflowCell: some View {
        Button(action: { appState.openStampArchive() }) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            Color.piloGoldDark.opacity(0.45),
                            style: StrokeStyle(lineWidth: 0.8, dash: [3, 2])
                        )
                        .frame(width: 52, height: 48)
                    Text("+\(appState.sidebarOverflowCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.piloGoldDark)
                }
                .rotationEffect(.degrees(-3))
                Text(Copy.Stamps.overflowMore(count: appState.sidebarOverflowCount, lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Copy.Stamps.allHint(lang))
    }
}

// MARK: - Single grid cell

private struct StampGridCell: View {
    let stamp: PromptStamp
    let lang: Language

    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    @State private var justPasted = false

    var body: some View {
        Button(action: paste) {
            VStack(spacing: 5) {
                PromptStampChip(stamp: stamp, size: .grid, rotated: false)
                    .scaleEffect(justPasted ? 1.15 : (isHovered ? 1.05 : 1.0))
                    .rotationEffect(.degrees(justPasted ? 6 : (isHovered ? 0 : -3)))
                Text(stamp.title.isEmpty ? Copy.Stamps.emptyTitle(lang) : stamp.title)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.piloGold.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(stamp.title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button { appState.openStampEditor(stamp) } label: {
                Label(Copy.Stamps.menuEdit(lang), systemImage: "pencil")
            }
            Button { appState.togglePinStamp(stamp.id) } label: {
                Label(
                    stamp.pinned ? Copy.Stamps.menuUnpin(lang) : Copy.Stamps.menuPin(lang),
                    systemImage: stamp.pinned ? "pin.slash" : "pin"
                )
            }
            Button { appState.pasteStamp(stamp) } label: {
                Label(Copy.Stamps.menuCopy(lang), systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                appState.deletePromptStamp(stamp.id)
            } label: {
                Label(Copy.Stamps.menuDelete(lang), systemImage: "trash")
            }
        }
    }

    private func paste() {
        appState.pasteStamp(stamp)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            justPasted = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    justPasted = false
                }
            }
        }
    }
}
