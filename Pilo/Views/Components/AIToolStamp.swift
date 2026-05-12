import SwiftUI

/// "在这仓库里配置了 X" 的可视化 tag。复用 `PiloChip(.tinted, .small)`，
/// 跟 healthPill 在同一视觉权重。**只读** 信号 —— 仅表示检测到 config，
/// 不暗示当前活跃使用。
struct AIToolStamp: View {

    let tool: AITool
    let lang: Language

    var body: some View {
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
        HStack(spacing: 6) {
            AIToolStamp(tool: .claudeCode, lang: .zh)
            AIToolStamp(tool: .cursor, lang: .zh)
            AIToolStamp(tool: .codex, lang: .zh)
        }
        HStack(spacing: 6) {
            AIToolStamp(tool: .gemini, lang: .zh)
            AIToolStamp(tool: .aider, lang: .zh)
        }
    }
    .padding()
    .background(Color.creamBg)
}
