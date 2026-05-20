import SwiftUI

/// 全局邮票召唤面板的 SwiftUI 内容。
///
/// 视觉：cream paper 卡 + gold border + shadow，跟 sidebar 邮票本同款；
/// 顶部 header（图标 + "邮票本" + ⌘⇧Y 副标）；
/// 主体 3 列 LazyVGrid PromptStampChip；
/// 空状态：引导用户去主窗口 pin 邮票。
///
/// 点击邮票 → `appState.pasteStamp` 全套（NSPasteboard + lastUsedAt + 音效 + toast）
/// → `onDismiss` 关闭面板。Toast 用 panel 内自带 ✓ 微动画，不依赖主窗口的 StampToastView。
struct StampQuickPanelView: View {

    let appState: AppState
    let onDismiss: () -> Void

    @State private var justCopiedStampId: UUID?

    private var lang: Language { appState.language }
    private var stamps: [PromptStamp] { appState.sidebarStamps }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .overlay(Color.piloGold.opacity(0.3))

            if stamps.isEmpty {
                emptyState
                    .padding(.vertical, 26)
                    .padding(.horizontal, 30)
            } else {
                stampsGrid
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 360)
        .frame(maxHeight: 480)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.piloPaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13))
                .foregroundStyle(Color.piloGoldDark)
            Text(Copy.Stamps.quickPanelTitle(lang))
                .font(.custom("Songti SC", size: 16).weight(.medium))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            // ✕ 关闭按钮——明确 close affordance（替代不存在的 ⌘⇧Y 提示）
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.cloudDivider.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)  // 试 Esc 触发（panel 是 key 时生效）
            .help(lang == .zh ? "关闭" : "Close")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Color.piloGoldDark.opacity(0.45))
            Text(Copy.Stamps.quickPanelEmpty(lang))
                .font(.piloSerifSubtitle)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stamps grid

    private var stampsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(stamps) { stamp in
                    stampCell(stamp)
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func stampCell(_ stamp: PromptStamp) -> some View {
        Button {
            justCopiedStampId = stamp.id
            appState.pasteStamp(stamp)
            // 短暂 checkmark 动画后关面板（150ms 让用户看到反馈）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onDismiss()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    PromptStampChip(stamp: stamp, size: .grid)
                    if justCopiedStampId == stamp.id {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.stampMint)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(stamp.title.isEmpty ? "—" : stamp.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(stamp.body.prefix(80) + (stamp.body.count > 80 ? "…" : ""))
        .animation(.easeOut(duration: 0.15), value: justCopiedStampId)
    }
}
