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
        VStack(spacing: 6) {
            toolbarHeader
            if !appState.isStampBookCollapsed {
                stickyNoteCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.isStampBookCollapsed)
    }

    // MARK: - Toolbar header（三段式：左 + / 中 标题 / 右 archive）

    /// 把"邮票本"标题嵌进 toolbar capsule 中间 —— 解决两按钮中间空、标题位置低的问题。
    /// 最右侧 chevron 控制便签卡片展开/折叠。
    private var toolbarHeader: some View {
        HStack(spacing: 0) {
            // 左：+ 新建邮票
            Button(action: { appState.openStampEditor() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.piloGoldDark)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Copy.Stamps.addNewHint(lang))

            Spacer(minLength: 4)

            // 中：邮票本 Songti italic gold（可点击 toggle —— 跟 chevron 等价的 secondary 入口）
            Button(action: toggleCollapsed) {
                Text(Copy.Stamps.sectionTitle(lang))
                    .font(.custom("Songti SC", size: 14).italic())
                    .tracking(1.0)
                    .foregroundStyle(Color.piloGoldDark)
                    .fixedSize()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(appState.isStampBookCollapsed
                  ? Copy.Stamps.expandHint(lang)
                  : Copy.Stamps.collapseHint(lang))

            Spacer(minLength: 4)

            // 右组：📕 archive + chevron 折叠 / 展开
            HStack(spacing: 2) {
                Button(action: { appState.openStampArchive() }) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            appState.totalStampCount == 0
                                ? Color.piloGoldDark.opacity(0.35)
                                : Color.piloGoldDark
                        )
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appState.totalStampCount == 0)
                .help(Copy.Stamps.allHint(lang))

                Button(action: toggleCollapsed) {
                    Image(systemName: appState.isStampBookCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.piloGoldDark)
                        .frame(width: 22, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(appState.isStampBookCollapsed
                      ? Copy.Stamps.expandHint(lang)
                      : Copy.Stamps.collapseHint(lang))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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

    private func toggleCollapsed() {
        appState.isStampBookCollapsed.toggle()
    }

    // MARK: - Sticky note card（下方便签纸 —— 标题已上移到 toolbar，内部直接展 grid）
    //
    // **对齐策略**：
    //   - 有邮票（stampsGrid）→ topLeading：邮票从左上开始贴，pin/unpin 不引起位置跳
    //   - empty / 无 pinned 提示 → center：mascot + CTA 居中是"提示"语义，跟 placeholder UI 一致
    //   - 这通过 inner VStack 顶部 + 底部 Spacer 实现 grid 模式靠顶；empty 模式整体居中

    private var stickyNoteCard: some View {
        ZStack {
            if appState.totalStampCount == 0 {
                emptyState     // 整 frame 居中
            } else if appState.sidebarStamps.isEmpty {
                noPinnedHint   // 整 frame 居中
            } else {
                stampsGrid
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60)
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
    //
    // 设计目标：让用户看一眼就知道这是个 prompt 库。
    //   - 3 张半透明 preview 邮票排成一行（"集邮册"感）
    //   - 1 行 explanation: "存常用 prompt，1 click 复制到任何 AI 工具"
    //   - + CTA 按钮

    private var emptyState: some View {
        VStack(spacing: 10) {
            // 3 张 faded preview 邮票 —— 暗示"可以填什么"
            HStack(spacing: 10) {
                ForEach([StampDesign.refactor, .bug, .idea], id: \.self) { d in
                    Image(d.imageName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 38, height: 35)
                        .opacity(0.4)
                        .rotationEffect(.degrees(Double.random(in: -6...6)))
                }
            }
            .padding(.top, 4)

            Text(Copy.Stamps.emptyExplanation(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)

            Button(action: { appState.openStampEditor() }) {
                Text("+ " + Copy.Stamps.emptyHint(lang))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
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
        // 3 列 grid，矩形 illustration 邮票 + 1 行 caption。
        // **alignment: .leading** —— 不满 row（如 2 张邮票占 col 1+2 留 col 3 空）
        // cell 靠左排，不会居中漂在中间。pin/unpin 时位置稳定。
        // 高于 9 张（3 行）—— 卡片内部 ScrollView 防止挤死 repo list。
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .center),
            count: 3
        )
        let shouldScroll = appState.sidebarStamps.count > 9
        let gridContent = LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(appState.sidebarStamps) { stamp in
                StampGridCell(stamp: stamp, lang: lang)
            }
            // overflow chip：邮票本里还有未钉的，引导去 archive 看全部
            if appState.sidebarOverflowCount > 0 {
                overflowCell
            }
        }

        return Group {
            if shouldScroll {
                ScrollView(showsIndicators: false) {
                    gridContent
                        .padding(.vertical, 2)
                }
                .frame(maxHeight: 270)
            } else {
                gridContent
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
                Text(Copy.Stamps.unpinnedMore(count: appState.sidebarOverflowCount, lang))
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
    @State private var sealRingScale: CGFloat = 0.6
    @State private var sealRingOpacity: Double = 0

    /// 24h 内用过 → 邮票上加金色 fresh dot
    private var isFresh: Bool {
        guard let last = stamp.lastUsedAt else { return false }
        return Date().timeIntervalSince(last) < 24 * 3600
    }

    /// hover tooltip：body 前 80 字 preview，比 title 更有决策辅助价值
    private var tooltip: String {
        let body = stamp.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return stamp.title }
        let preview = body.prefix(80)
        return body.count > 80 ? "\(preview)…" : String(preview)
    }

    var body: some View {
        Button(action: paste) {
            VStack(spacing: 5) {
                ZStack {
                    // 金色光环 ring —— paste 时 expand + fade，邮戳力量感（视觉保留盖章感，文案用「誊抄」）
                    Circle()
                        .stroke(Color.piloGoldDark.opacity(sealRingOpacity), lineWidth: 1.2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(sealRingScale)
                        .allowsHitTesting(false)

                    PromptStampChip(stamp: stamp, size: .grid, rotated: false)
                        .scaleEffect(justPasted ? 1.15 : (isHovered ? 1.05 : 1.0))
                        .rotationEffect(.degrees(justPasted ? 6 : (isHovered ? 0 : -3)))

                    // 右上角 fresh dot —— 24h 内用过
                    if isFresh {
                        Circle()
                            .fill(Color.piloGold)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.piloPaper, lineWidth: 1)
                            )
                            .offset(x: 22, y: -20)
                            .allowsHitTesting(false)
                    }

                    // hover 右下角 ⋯ ghost icon —— 右键 affordance
                    if isHovered {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.piloGoldDark.opacity(0.7))
                            .padding(2)
                            .background(Circle().fill(Color.piloPaper.opacity(0.85)))
                            .offset(x: 20, y: 18)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 50)

                Text(stamp.title.isEmpty ? Copy.Stamps.emptyTitle(lang) : stamp.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
        .help(tooltip)
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
        // chip 邮戳 spring 抖动
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            justPasted = true
        }
        // 金色光环 expand + fade —— 0.6x 起步、瞬间 fade-in 后 1.4x 慢扩散并 fade-out
        sealRingScale = 0.6
        sealRingOpacity = 0.85
        withAnimation(.easeOut(duration: 0.55)) {
            sealRingScale = 1.6
            sealRingOpacity = 0
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
