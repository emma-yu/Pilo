import SwiftUI

/// "在这仓库里配置了 X" 的可视化 stamp。
/// 跟 `AILauncher` menu 里那种"启动这工具"按钮不同 —— 这个是**只读**信号，
/// 表示"AIToolRepoDetector 在仓库根看到了 X 的 config 文件"。
///
/// 两种 style：
///   - `.iconOnly`（sidebar 用）：圆形 16pt mini 邮戳，仅 icon
///   - `.full`（detail view 用）：复用 `PiloChip(.tinted, .small)`，icon + 名字
struct AIToolStamp: View {

    let tool: AITool
    let style: Style
    let lang: Language

    enum Style {
        case iconOnly      // sidebar 用，省空间
        case full          // detail view 用，icon + 名字
    }

    var body: some View {
        switch style {
        case .iconOnly:
            iconStamp
        case .full:
            fullChip
        }
    }

    // MARK: - iconOnly 邮戳样式

    private var iconStamp: some View {
        Image(systemName: tool.symbol)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(tool.tintColor)
            .frame(width: 16, height: 16)
            .background(
                Circle()
                    .fill(tool.tintColor.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(tool.tintColor.opacity(0.4), lineWidth: 0.5)
            )
            .help(Copy.AIRepo.stampTooltip(tool: tool, lang))
            .accessibilityLabel(Copy.AIRepo.stampTooltip(tool: tool, lang))
    }

    // MARK: - full chip 样式

    private var fullChip: some View {
        PiloChip(
            icon: tool.symbol,
            text: tool.displayName,
            tint: tool.tintColor,
            style: .tinted,
            size: .small
        )
        .help(Copy.AIRepo.stampTooltip(tool: tool, lang))
        .accessibilityLabel(Copy.AIRepo.stampTooltip(tool: tool, lang))
    }

    // MARK: - 显示优先级

    /// 多个 tool 检测到时，按固定优先级排序。
    /// Pilo 自己的"伙伴工具" Claude Code 排第一；剩下按市占率粗略排。
    /// `nonisolated`：pure 函数，方便单测在非 MainActor 上下文调用
    nonisolated static func sortedForDisplay(_ tools: Set<AITool>) -> [AITool] {
        let priority: [AITool: Int] = [
            .claudeCode: 0,
            .cursor:     1,
            .codex:      2,
            .gemini:     3,
            .aider:      4,
            .windsurf:   5,
            .vscode:     6,
        ]
        return tools.sorted { (priority[$0] ?? 99) < (priority[$1] ?? 99) }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("Icon-only (sidebar):")
            .font(.caption)
        HStack(spacing: 4) {
            AIToolStamp(tool: .claudeCode, style: .iconOnly, lang: .zh)
            AIToolStamp(tool: .cursor, style: .iconOnly, lang: .zh)
            AIToolStamp(tool: .codex, style: .iconOnly, lang: .zh)
            AIToolStamp(tool: .gemini, style: .iconOnly, lang: .zh)
            AIToolStamp(tool: .aider, style: .iconOnly, lang: .zh)
        }
        Divider()
        Text("Full chip (detail):")
            .font(.caption)
        VStack(alignment: .leading, spacing: 6) {
            AIToolStamp(tool: .claudeCode, style: .full, lang: .zh)
            AIToolStamp(tool: .cursor, style: .full, lang: .zh)
            AIToolStamp(tool: .codex, style: .full, lang: .zh)
            AIToolStamp(tool: .gemini, style: .full, lang: .zh)
            AIToolStamp(tool: .aider, style: .full, lang: .zh)
        }
    }
    .padding()
    .background(Color.creamBg)
}
