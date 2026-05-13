import SwiftUI

/// Sidebar 底部「邮票本」widget。
///
/// 三态：
///   - empty（无邮票）：mascot icon + 「还没有邮票」+ 「+ 盖第一张」
///   - few（≤5 张钉住）：列出钉住邮票
///   - many（> 5 张钉住）：列出前 5 + 「…还有 N 张」点击进 archive
///
/// **隔离 state**：hover state 在每个 StampRow 自己的 @State 里，
/// 切换不引发整个 PanelSidebar re-render
struct PromptStampBookSidebar: View {

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if appState.totalStampCount == 0 {
                emptyState
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            } else {
                stampList
                    .padding(.top, 2)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .background(
            // 跟 sidebar bg 同色但 slightly differentiate
            Rectangle()
                .fill(Color.piloPaper.opacity(0.25))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.piloGold.opacity(0.25))
                        .frame(height: 0.5)
                }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            // "— 邮票本 —" 衬线 italic gold（金线 ornament 缩小版）
            HStack(spacing: 4) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.piloGold.opacity(0), Color.piloGold.opacity(0.5)],
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
                            colors: [Color.piloGold.opacity(0.5), Color.piloGold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
            }

            Spacer(minLength: 6)

            // "+" 新建
            Button(action: { appState.openStampEditor() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.piloGoldDark)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.piloGold.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help(Copy.Stamps.addNewHint(lang))

            // "⋯" 看全部
            if appState.totalStampCount > 0 {
                Button(action: { appState.openStampArchive() }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.piloGoldDark)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.piloGold.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help(Copy.Stamps.allHint(lang))
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 22))
                .foregroundStyle(Color.piloGoldDark.opacity(0.55))
                .padding(.top, 8)
            Text(Copy.Stamps.emptyTitle(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.inkSecondary)
            Button(action: { appState.openStampEditor() }) {
                Text("+ " + Copy.Stamps.emptyHint(lang))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.piloGold.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(Color.piloGold.opacity(0.4), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stamp list

    private var stampList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(appState.sidebarStamps) { stamp in
                StampRow(stamp: stamp, lang: lang)
            }

            if appState.sidebarOverflowCount > 0 {
                Button(action: { appState.openStampArchive() }) {
                    Text(Copy.Stamps.overflowMore(count: appState.sidebarOverflowCount, lang))
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, 36)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .help(Copy.Stamps.allHint(lang))
            } else if appState.totalStampCount > 0 && appState.sidebarStamps.isEmpty {
                // 有邮票但都没钉 —— 提示用户去 archive 钉
                Button(action: { appState.openStampArchive() }) {
                    Text(lang == .zh ? "去钉几张到 sidebar" : "Pin some to sidebar")
                        .font(.piloSerifCaption)
                        .italic()
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.leading, 4)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Single Row

private struct StampRow: View {
    let stamp: PromptStamp
    let lang: Language

    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    @State private var justPasted = false   // 触发 0.4s 邮戳动画

    var body: some View {
        Button(action: paste) {
            HStack(spacing: 10) {
                PromptStampChip(stamp: stamp, size: .compact)
                    .scaleEffect(justPasted ? 1.15 : 1.0)
                    .rotationEffect(.degrees(justPasted ? 6 : 0))
                Text(stamp.title.isEmpty ? Copy.Stamps.emptyTitle(lang) : stamp.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.piloGold.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Copy.Stamps.hoverHint(lang))
        .onHover { hovering in
            isHovered = hovering
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
        // 触发 0.4s 邮戳"盖章"动画
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
