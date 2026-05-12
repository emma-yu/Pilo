import Foundation
import AppKit

/// 用户机器上已安装的 AI coding 工具。Pilo 启动时检测一次缓存到 AppState。
/// 不依赖 PATH —— IDE 用 URL scheme（NSWorkspace），CLI 用 Terminal.app 走 AppleScript。
enum AITool: String, CaseIterable, Sendable, Hashable, Identifiable {
    case cursor       // IDE — URL scheme
    case windsurf     // IDE — URL scheme
    case vscode       // IDE — URL scheme
    case claudeCode   // CLI — Terminal
    case codex        // CLI — Terminal

    var id: String { rawValue }

    /// 用户能看的中文 / 英文显示名
    var displayName: String {
        switch self {
        case .cursor:     return "Cursor"
        case .windsurf:   return "Windsurf"
        case .vscode:     return "VS Code"
        case .claudeCode: return "Claude Code"
        case .codex:      return "Codex"
        }
    }

    /// SF Symbol 给 menu 用（每个工具都有 icon 视觉提示）
    var symbol: String {
        switch self {
        case .cursor, .windsurf:  return "sparkles"
        case .vscode:             return "chevron.left.forward.slash.chevron.right"
        case .claudeCode:         return "terminal.fill"
        case .codex:              return "bolt.fill"
        }
    }

    /// 工具类型决定启动机制
    enum Kind { case ide, cli }
    var kind: Kind {
        switch self {
        case .cursor, .windsurf, .vscode: return .ide
        case .claudeCode, .codex:         return .cli
        }
    }

    /// CLI 命令名（也用作 `which` 检测）
    var commandName: String {
        switch self {
        case .cursor:     return "cursor"
        case .windsurf:   return "windsurf"
        case .vscode:     return "code"
        case .claudeCode: return "claude"
        case .codex:      return "codex"
        }
    }

    /// IDE 的 URL scheme（IDE 类型才有）
    var urlScheme: String? {
        switch self {
        case .cursor:    return "cursor"
        case .windsurf:  return "windsurf"
        case .vscode:    return "vscode"
        default:         return nil
        }
    }

    /// 启动：在 repoPath 打开这个 AI tool。IDE 走 URL scheme（无依赖最稳），
    /// CLI 走 Terminal.app + AppleScript（`cd` + 执行命令）。
    @MainActor
    func launch(repoPath: String) {
        switch kind {
        case .ide:
            launchIDE(repoPath: repoPath)
        case .cli:
            launchCLI(repoPath: repoPath)
        }
    }

    @MainActor
    private func launchIDE(repoPath: String) {
        guard let scheme = urlScheme else { return }
        // 标准格式：scheme://file/PATH  或 scheme:///PATH
        // Cursor / VS Code / Windsurf 都接受 "scheme://file/{absolutePath}"
        let encoded = repoPath
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repoPath
        guard let url = URL(string: "\(scheme)://file\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func launchCLI(repoPath: String) {
        // AppleScript 注入安全：repoPath 来自 git scanner（不是用户原始输入），
        // 但仍 escape `\` 和 `"` 防边缘 case
        let escaped = repoPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "cd \\"\(escaped)\\" && \(commandName)"
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
