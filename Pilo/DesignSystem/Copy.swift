import Foundation

/// 所有面向用户的字符串都集中在此。**不要**在视图层硬编码文案。
///
/// 每个方法接收 `Tone` 参数（或环境读取），根据 friendly / minimal 返回不同字符串。
/// 长期目标：迁移到 Xcode 16 String Catalog (`.xcstrings`) 以支持 zh+en。
/// 当前阶段：中文为主，结构留好。
enum Copy {

    // MARK: - 菜单栏 Popover

    static func menubarAllSynced(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "所有仓库都同步啦～\n去做点别的吧 ✨"
        case .minimal:  "所有仓库已同步"
        }
    }

    static func menubarPendingHeader(_ tone: Tone, count: Int) -> String {
        switch tone {
        case .friendly: "咕咕～你有 \(count) 个仓库待处理"
        case .minimal:  "\(count) 个仓库待处理"
        }
    }

    static func menubarScanInProgress(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "正在找你的仓库..."
        case .minimal:  "扫描中..."
        }
    }

    static func menubarOffline(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "现在没网呢，我先帮你看着～"
        case .minimal:  "网络断开"
        }
    }

    static func menubarKillSwitchBanner(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "⚠️ 安全检查已关闭 · 点击恢复"
        case .minimal:  "安全检查已关闭"
        }
    }

    static let menubarPushAllButton    = "一键推送全部"
    static let menubarOpenMainWindow   = "打开主面板"
    static let menubarSettings         = "设置..."
    static let menubarQuit             = "退出 Pilo"

    // MARK: - 空状态

    static func emptyNoRepos(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "咕咕～还没有发现仓库呢。\n去设置里添加扫描目录吧 ✨"
        case .minimal:  "没有发现仓库\n请在设置中添加扫描目录"
        }
    }

    static func gitNotFound(_ tone: Tone) -> String {
        switch tone {
        case .friendly: "哎呀～没在系统里找到 git 命令。\n试试在终端运行：xcode-select --install"
        case .minimal:  "未找到 git。请运行：xcode-select --install"
        }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let welcomeTitle    = "咕咕～"
        static let welcomeBody     = "我是 Pilo，一只帮你安全推送代码的小信鸽"
        static let welcomeFeature1 = "自动扫描你的本地仓库"
        static let welcomeFeature2 = "push 之前帮你查一遍敏感信息"
        static let welcomeFeature3 = "一切都在你的电脑上完成，代码不会离开本地"
        static let welcomeContinue = "继续"

        static let directoriesTitle = "告诉我去哪里找你的代码？"
        static let directoriesHint  = "我会在这些目录下找所有的 Git 仓库\n会自动跳过 node_modules、vendor 等"
        static let directoriesAdd   = "+ 添加目录"
        static let directoriesEmpty = "还没有选择目录"
        static let directoriesSkip  = "跳过"
        static let directoriesNext  = "继续"

        static let privacyTitle = "关于隐私，我要明确告诉你"
        static let privacyBody  = """
        ✅ 代码、commit、diff 都只在你的电脑上分析
        ✅ 不调用任何 LLM 或云端 API
        ✅ 唯一的网络行为是：
           • 后台定期 git fetch（和你平时用 git 一样）
           • 你主动触发的 git push
           • 可选的 GitHub API 调用（检测仓库可见性，需要你提供 token）

        👀 你可以随时在「设置 → 关于 → 操作日志」里查看 Pilo 做过的每一件事
        """
        static let privacyAck = "我了解了"

        static let completeTitleFound = "找到了 %d 个仓库"
        static let completeTitleEmpty = "暂时没找到仓库"
        static let completeGitInfo    = "Pilo 找到了 %@ 位于 %@"
        static let completeNoGit      = "未找到 git 命令"
        static let completeOpen       = "打开主面板"
        static let completeStayInMenubar = "提示：Pilo 会一直待在菜单栏 ↑"
    }

    // MARK: - 推送（Phase 5）

    enum Push {

        // Preflight 阶段
        static func preflightTitle(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "准备推送啦"
            case .minimal:  "确认推送"
            }
        }

        static func preflightSubtitle(_ tone: Tone, count: Int) -> String {
            switch tone {
            case .friendly: "我要把 \(count) 个 commit 飞到远端，确认一下？"
            case .minimal:  "将推送 \(count) 个 commit"
            }
        }

        static let preflightCommitsHeader = "本次推送的 commit"
        static let preflightFirstPushHint = "首次推送 · 会自动设置 upstream（-u）"
        static let preflightScanPlaceholder = "🔒 安全检查（Phase 6 待启用）"

        static func pushButton(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "✨ 推送 ✨"
            case .minimal:  "推送"
            }
        }

        static func cancelButton(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "再想想"
            case .minimal:  "取消"
            }
        }

        // Running 阶段
        static func runningTitle(_ tone: Tone, remote: String) -> String {
            switch tone {
            case .friendly: "正在飞往 \(remote)..."
            case .minimal:  "推送到 \(remote)..."
            }
        }

        // Completed 阶段 - 成功
        static func successTitle(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "🌸 推送完成"
            case .minimal:  "推送完成"
            }
        }

        static func successSubtitle(_ tone: Tone, count: Int) -> String {
            switch tone {
            case .friendly: "\(count) 个 commit 已送达 ✨"
            case .minimal:  "\(count) 个 commit 已送达"
            }
        }

        // Completed 阶段 - 失败
        static func failureTitle(_ tone: Tone, outcome: PushOutcome) -> String {
            switch (outcome, tone) {
            case (.authenticationFailed, .friendly):  "🥲 没认证通过"
            case (.authenticationFailed, .minimal):   "认证失败"
            case (.nonFastForward, .friendly):        "😯 远端有新内容"
            case (.nonFastForward, .minimal):         "Non-fast-forward"
            case (.hookRejected, .friendly):          "🛑 pre-push hook 拦下了"
            case (.hookRejected, .minimal):           "Pre-push hook 拒绝"
            case (.networkError, .friendly):          "🌧️ 网络好像不通"
            case (.networkError, .minimal):           "网络错误"
            case (.noUpstreamConfigured, .friendly):  "🤔 还没配 upstream"
            case (.noUpstreamConfigured, .minimal):   "未配置 upstream"
            case (.unknown, .friendly):               "咕咕没飞过去"
            case (.unknown, .minimal):                "推送失败"
            case (.success, _):                        ""  // 不应该到这里
            }
        }

        static func failureExplanation(_ outcome: PushOutcome) -> String {
            switch outcome {
            case .authenticationFailed:
                """
                看起来 git 不知道用什么凭证来认证。最常见的两个解决方法：

                • 如果用 HTTPS：在终端运行一次 `git push`，让 macOS Keychain 缓存你的 GitHub Personal Access Token
                • 如果用 SSH：确认你的 SSH key 已经在 ssh-agent 里（`ssh-add -l`），并且公钥已加到 GitHub 设置
                """
            case .nonFastForward:
                """
                远端比本地新，需要先把远端的改动拉下来：

                • 在终端运行 `git pull --rebase` 或 `git fetch && git rebase origin/<branch>`
                • 解决冲突（如果有）后重新推送
                """
            case .hookRejected:
                """
                你或团队配置的 pre-push hook 拒绝了这次推送。具体原因在下方 stderr 里。
                修复 hook 提示的问题后重试。
                """
            case .networkError:
                """
                没连上远端服务器。检查一下：

                • Wi-Fi / 代理是否正常
                • 远端 URL 是否拼写正确
                """
            case .noUpstreamConfigured:
                """
                这个分支还没有 upstream。Pilo 应该自动加 -u，但似乎被拒绝了。
                可以在终端运行 `git push -u origin <branch>` 排查。
                """
            case .unknown, .success:
                "下方 stderr 里有详细信息。"
            }
        }

        static let copyStderrButton  = "复制错误信息"
        static let openTerminalButton = "在终端打开"
        static let closeButton        = "关闭"
        static let doneButton         = "好啦"

        // Push 入口（详情视图按钮）
        static func pushEntryButton(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "✨ 推送"
            case .minimal:  "推送"
            }
        }

        static let pushDisabledHint = "没有可推送的 commit"
    }

    // MARK: - 安全扫描（Phase 6）

    enum Scan {

        static func sectionHeader(_ tone: Tone, count: Int) -> String {
            switch (count, tone) {
            case (0, .friendly): "✅ 安全检查通过"
            case (0, .minimal):  "安全检查通过"
            case (_, .friendly): "哎呀～发现 \(count) 处可能要看看"
            case (_, .minimal):  "发现 \(count) 处"
            }
        }

        static func killSwitchSkipped(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "🕶️ 安全检查已暂停（紧急模式）"
            case .minimal:  "安全检查已暂停"
            }
        }

        static let critical    = "高危"
        static let warning     = "提示"
        static let jumpToFile  = "在 Finder 中显示"
        static let markFP      = "标记为误报"
        static let markFPHere  = "仅这个文件"
        static let markFPRule  = "整个仓库都不再扫这条规则"
        static let markFPCancel = "再想想"
        static let markFPTitle = "怎么标记？"
        static let markFPSubtitle = "下次扫描会按你选的范围跳过这一条。"

        // Critical 时 Push 按钮文案
        static func pushBypassButton(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "我已了解，仍然推送"
            case .minimal:  "确认推送"
            }
        }

        // BypassConfirmDialog
        static func bypassConfirmTitle(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "🕊️ 真的吗？"
            case .minimal:  "确认绕过安全检查"
            }
        }

        static let bypassConfirmDesc = """
        推送之后这些 key 会进入 GitHub 历史，
        即使后续删除也很难真正清除。
        通常需要重新生成 key 才能彻底解决。

        📝 建议先做的事：
          1. 在密钥服务商后台 revoke 这些 key
          2. 重新生成新 key
          3. 把新 key 放到 .env 而不是源码

        如果你坚持要推送，请输入仓库名确认：
        """

        static let bypassConfirmInputPlaceholder = "在这里输入仓库名"
        static let bypassConfirmYes = "我已了解，推送"
        static let bypassConfirmNo  = "取消"
        static let bypassNameMismatch = "仓库名不匹配"
    }

    // MARK: - Kill switch（Phase 6）

    enum KillSwitch {

        static func bannerInMenuBar(_ tone: Tone, remainingHours: Int) -> String {
            switch tone {
            case .friendly: "🕶️ 安全检查已关闭（剩 \(remainingHours) 小时自动恢复）· 点击立即恢复"
            case .minimal:  "安全检查已关闭（\(remainingHours) 小时后恢复）· 立即恢复"
            }
        }

        static let settingsSectionTitle = "安全检查"
        static let settingsToggleEnabled  = "启用敏感信息扫描"
        static let settingsToggleDescription = "推送前扫描 diff，发现 API key / token / 私钥等。规则集来自 Pilo 内置的 25 条精挑模板，纯本地匹配。"

        static let settingsKillSwitchTitle = "紧急关闭安全检查"
        static let settingsKillSwitchDesc  = "暂时关闭所有安全扫描，让 push 可以无阻通过。24 小时后自动恢复——避免你忘了自己关过。"
        static let settingsKillSwitchActivateButton = "暂时关闭 24 小时"
        static let settingsKillSwitchActiveLabel  = "已关闭，%d 小时后恢复"
        static let settingsKillSwitchRestoreButton = "立即恢复"
    }

    // MARK: - Mascot 无障碍标签

    enum MascotA11y {
        static func label(for mood: PiloMascot.Mood, tone: Tone) -> String {
            switch (mood, tone) {
            case (.sleeping, .friendly):   "Pilo 正在小睡"
            case (.sleeping, .minimal):    "应用状态：空闲"
            case (.alert, .friendly):      "Pilo 睁眼歪头看"
            case (.alert, .minimal):       "应用状态：有待处理项"
            case (.worried, .friendly):    "Pilo 有点担心"
            case (.worried, .minimal):     "应用状态：发现风险"
            case (.happy, .friendly):      "Pilo 很开心"
            case (.happy, .minimal):       "应用状态：完成"
            case (.raining, .friendly):    "Pilo 在撑伞"
            case (.raining, .minimal):     "应用状态：离线"
            case (.flying, .friendly):     "Pilo 飞起来了"
            case (.flying, .minimal):      "应用状态：传输中"
            case (.sunglasses, .friendly): "Pilo 戴着墨镜"
            case (.sunglasses, .minimal):  "应用状态：检查已关闭"
            }
        }
    }
}
