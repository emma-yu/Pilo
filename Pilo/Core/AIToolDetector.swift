import Foundation

/// 检测用户机器上已安装的 AI coding 工具。Pilo 启动时跑一次，结果缓存到 AppState。
/// 实现方式：在常见路径 + `which` 命令检测对应可执行文件。
enum AIToolDetector {

    /// 检测哪些 AI tool 装了。同步阻塞，但只跑几个 which，毫秒级。
    /// 实际调用方应放在 Task 里避免占 MainActor 太久。
    static func detect() -> [AITool] {
        AITool.allCases.filter { isInstalled($0) }
    }

    /// 单工具检测：
    ///   - IDE 类（有 URL scheme）：用 LaunchServices 查询 scheme 注册者
    ///   - CLI 类（没 URL scheme）：用 which / 检查常见安装路径
    static func isInstalled(_ tool: AITool) -> Bool {
        if let scheme = tool.urlScheme {
            // IDE：查 URL scheme 注册（最可靠，不依赖 PATH）
            if let _ = LSCopyDefaultApplicationURLForURL(
                URL(string: "\(scheme)://")! as CFURL,
                .editor,
                nil
            )?.takeRetainedValue() {
                return true
            }
            // fallback：检测 CLI（IDE 通常也带 CLI）
        }
        return commandExists(tool.commandName)
    }

    /// 跑 `/usr/bin/which X`，exit 0 + stdout 非空 = 命令存在
    private static func commandExists(_ command: String) -> Bool {
        // 常见路径优先检查（不 spawn process）
        let commonPaths = [
            "/usr/local/bin/", "/opt/homebrew/bin/", "/usr/bin/",
            // npm 全局 / nvm 等典型路径
            "\(NSHomeDirectory())/.nvm/versions/node/",
            "\(NSHomeDirectory())/.local/bin/",
            "\(NSHomeDirectory())/.cargo/bin/",
        ]
        for prefix in commonPaths {
            if FileManager.default.isExecutableFile(atPath: prefix + command) {
                return true
            }
        }
        // fallback：spawn which（用户 shell 可能 alias 了，仍能命中）
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
