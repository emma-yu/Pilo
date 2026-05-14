import Foundation
import AppKit
import SwiftUI

/// 用户机器上已安装的 AI coding 工具。Pilo 启动时检测一次缓存到 AppState。
/// 不依赖 PATH —— IDE 用 URL scheme（NSWorkspace），CLI 用 Terminal.app 走 AppleScript。
enum AITool: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case cursor       // IDE — URL scheme
    case windsurf     // IDE — URL scheme
    case vscode       // IDE — URL scheme
    case claudeCode   // CLI — Terminal
    case codex        // CLI — Terminal
    case aider        // CLI — Terminal（conversational; CONVENTIONS.md + .aider.* files）
    case gemini       // CLI — Terminal（Google Gemini Code Assist; GEMINI.md / .gemini/）

    var id: String { rawValue }

    /// 用户能看的中文 / 英文显示名
    var displayName: String {
        switch self {
        case .cursor:     return "Cursor"
        case .windsurf:   return "Windsurf"
        case .vscode:     return "VS Code"
        case .claudeCode: return "Claude Code"
        case .codex:      return "Codex"
        case .aider:      return "Aider"
        case .gemini:     return "Gemini"
        }
    }

    /// SF Symbol 给 menu 用（每个工具都有 icon 视觉提示）
    var symbol: String {
        switch self {
        case .cursor:     return "sparkles"
        case .windsurf:   return "wind"
        case .vscode:     return "chevron.left.forward.slash.chevron.right"
        case .claudeCode: return "terminal.fill"
        case .codex:      return "bolt.fill"
        case .aider:      return "checkmark.bubble.fill"   // conversational CLI
        case .gemini:     return "diamond.fill"            // Gemini logo 是钻石/双子形
        }
    }

    /// Pilo 设计系统色调，跟 sidebar dot / health pill / category stamp 一致
    var tintColor: Color {
        switch self {
        case .cursor:     return .piloBlue
        case .windsurf:   return .mintSafe
        case .vscode:     return .lavenderInfo
        case .claudeCode: return .stampRed
        case .codex:      return .piloGoldDark
        case .aider:      return .amberWarn               // 暖琥珀（避开现有 5 色）
        case .gemini:     return .piloAccent              // 心粉（独特，避开蓝/绿/灰）
        }
    }

    /// 工具类型决定启动机制
    enum Kind { case ide, cli }
    var kind: Kind {
        switch self {
        case .cursor, .windsurf, .vscode:       return .ide
        case .claudeCode, .codex, .aider, .gemini: return .cli
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
        case .aider:      return "aider"
        case .gemini:     return "gemini"
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
            #if DEBUG
            if let err = error { print("[AITool] AppleScript error:", err) }
            #endif
        }
    }
}
