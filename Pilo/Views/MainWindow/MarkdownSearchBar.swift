import SwiftUI

/// MarkdownPreviewSheet ⌘F 触发的搜索条。
///
/// 视觉：
///   - 高度 ~36pt，cream paper bg + 底部金色 hairline
///   - 🔍 magnifyingglass + TextField + "3/12" counter + ↑↓ nav + ✕
///   - autofocus via @FocusState bound to caller's state
///   - Esc 关搜索 → 把焦点还给 sheet（不冒泡给 sheet 的 cancelAction）
///
/// caller 持有所有状态（query / hits / currentHitIndex / focused），
/// 本 view 是纯 UI 壳。
struct MarkdownSearchBar: View {

    @Binding var query: String
    @Binding var currentHitIndex: Int
    let hitCount: Int
    let lang: Language
    let onClose: () -> Void
    /// 由 caller 传入的 FocusState binding —— Esc 处理需要知道 focus 状态
    var focusBinding: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.piloGoldDark)

            TextField(Copy.Docs.searchPlaceholder(lang), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkPrimary)
                .focused(focusBinding)
                .onKeyPress(.escape) {
                    onClose()
                    return .handled   // 不冒泡给 sheet 的 .cancelAction
                }
                .onKeyPress(.return) {
                    advance(by: 1)
                    return .handled
                }
                .onSubmit { advance(by: 1) }

            // 计数器
            counterPill

            // 上 / 下
            Button(action: { advance(by: -1) }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hitCount > 0 ? Color.piloGoldDark : Color.inkTertiary)
            }
            .buttonStyle(.plain)
            .disabled(hitCount == 0)
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .help(lang == .zh ? "上一个 (⌘⇧G)" : "Previous (⌘⇧G)")

            Button(action: { advance(by: 1) }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hitCount > 0 ? Color.piloGoldDark : Color.inkTertiary)
            }
            .buttonStyle(.plain)
            .disabled(hitCount == 0)
            .keyboardShortcut("g", modifiers: [.command])
            .help(lang == .zh ? "下一个 (⌘G)" : "Next (⌘G)")

            // 关闭
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(5)
                    .background(Circle().fill(Color.cloudDivider.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .help(lang == .zh ? "关闭搜索 (Esc)" : "Close search (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.piloPaper.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.piloGold.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var counterPill: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            EmptyView()
        } else if hitCount == 0 {
            Text(Copy.Docs.searchNoMatch(lang))
                .font(.piloSerifCaption)
                .italic()
                .foregroundStyle(Color.roseDanger)
        } else {
            Text(Copy.Docs.searchCount(current: currentHitIndex + 1, total: hitCount, lang))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.inkSecondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }

    private func advance(by delta: Int) {
        guard hitCount > 0 else { return }
        let n = hitCount
        // 环形：超出界限回绕；负值用 ((x % n) + n) % n
        let raw = currentHitIndex + delta
        currentHitIndex = ((raw % n) + n) % n
    }
}
