import Foundation

/// 所有面向用户的字符串都集中在此。**不要**在视图层硬编码文案。
///
/// 维度：
///   - **tone**: .friendly（温柔可爱）/ .minimal（信息密度优先）
///   - **language**: .zh（简体中文）/ .en（英文）
///
/// 共 4 个组合。每个函数返回根据 tone + language 解析的字符串。
///
/// 调用模式：
///   `Copy.menubarAllSynced(tone: appState.tone, lang: appState.language)`
///
/// 中文方向：当代温柔可爱网络语言，但**克制**——避开"yyds/绝绝子/家人们"等过气梗
/// 英文方向：friendly + 信鸽 metaphor，但避免"uwu / no cap / tbh"等 datable slang
enum Copy {

    /// 本地化字符串容器——一处定义两语，按 language 解析
    struct Loc {
        let zh: String
        let en: String
        func text(_ lang: Language) -> String {
            switch lang { case .zh: return zh; case .en: return en }
        }
    }

    // MARK: - 菜单栏 popover

    static func menubarAllSynced(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "所有仓库都同步啦～\n去做点别的事呀 ✨",
                en: "All caught up ✨\nGo take a breather, friend"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "所有仓库已同步",
                en: "All synced"
            ).text(lang)
        }
    }

    static func menubarPendingHeader(_ tone: Tone, _ lang: Language = .zh, count: Int) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "咕咕～有 \(count) 个仓库等着寄出去呀",
                en: "Coo coo~ \(count) repos ready to fly"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "\(count) 个仓库待处理",
                en: "\(count) pending"
            ).text(lang)
        }
    }

    static func menubarScanInProgress(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "在找你的仓库...",
                en: "Sniffing out your repos..."
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "扫描中",
                en: "Scanning"
            ).text(lang)
        }
    }

    static func menubarOffline(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "网络打了个盹儿，我先帮你记着～",
                en: "WiFi's napping, I'll hold onto these for now~"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "网络断开",
                en: "Offline"
            ).text(lang)
        }
    }

    static func menubarKillSwitchBanner(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "🕶️ 安全检查暂停中 · 点这里叫醒我",
                en: "🕶️ Watch mode paused · tap to wake me"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "安全检查已关闭 · 点击恢复",
                en: "Scanner off · tap to restore"
            ).text(lang)
        }
    }

    /// 这几个不涉及温柔/极简的中性 label，但要双语
    static func menubarPushAllButton(_ lang: Language = .zh) -> String {
        Loc(zh: "一键推送全部", en: "Push all").text(lang)
    }
    static func menubarOpenMainWindow(_ lang: Language = .zh) -> String {
        Loc(zh: "打开主面板", en: "Open main window").text(lang)
    }
    static func menubarSettings(_ lang: Language = .zh) -> String {
        Loc(zh: "设置...", en: "Settings...").text(lang)
    }
    static func menubarQuit(_ lang: Language = .zh) -> String {
        Loc(zh: "退出 Pilo", en: "Quit Pilo").text(lang)
    }

    // 保留旧静态属性（用 .zh 默认）保证 backward compat
    static let menubarPushAllButton    = "一键推送全部"
    static let menubarOpenMainWindow   = "打开主面板"
    static let menubarSettings         = "设置..."
    static let menubarQuit             = "退出 Pilo"

    // MARK: - 空状态 / 错误

    static func emptyNoRepos(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "咕咕～还没发现仓库呢。\n去设置里添加扫描目录吧 ✨",
                en: "Coo~ no repos here yet.\nAdd a scan folder in Settings ✨"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "没有发现仓库\n请在设置中添加扫描目录",
                en: "No repos found\nAdd a scan folder in Settings"
            ).text(lang)
        }
    }

    static func gitNotFound(_ tone: Tone, _ lang: Language = .zh) -> String {
        switch tone {
        case .friendly:
            return Loc(
                zh: "诶诶～没找到 git。\n在终端跑一下：xcode-select --install",
                en: "Hmm... can't find git.\nRun this in Terminal: xcode-select --install"
            ).text(lang)
        case .minimal:
            return Loc(
                zh: "未找到 git。运行：xcode-select --install",
                en: "git not found. Run: xcode-select --install"
            ).text(lang)
        }
    }

    // MARK: - Onboarding

    enum Onboarding {

        static func welcomeTitle(_ lang: Language = .zh) -> String {
            Loc(zh: "咕咕～", en: "Coo coo~").text(lang)
        }

        static func welcomeBody(_ lang: Language = .zh) -> String {
            Loc(
                zh: "我是 Pilo，一只帮你安全送代码的小信鸽",
                en: "I'm Pilo, a little pigeon who delivers your code safely"
            ).text(lang)
        }

        static func welcomeFeature1(_ lang: Language = .zh) -> String {
            Loc(
                zh: "自动找到你电脑上的仓库",
                en: "Finds all your local repos"
            ).text(lang)
        }
        static func welcomeFeature2(_ lang: Language = .zh) -> String {
            Loc(
                zh: "push 前帮你查一遍敏感信息",
                en: "Checks for secrets before pushing"
            ).text(lang)
        }
        static func welcomeFeature3(_ lang: Language = .zh) -> String {
            Loc(
                zh: "一切都在你电脑上做，代码不会离开本地",
                en: "All local — your code never leaves your Mac"
            ).text(lang)
        }
        static func welcomeContinue(_ lang: Language = .zh) -> String {
            Loc(zh: "继续", en: "Continue").text(lang)
        }

        static func directoriesTitle(_ lang: Language = .zh) -> String {
            Loc(
                zh: "告诉我去哪里找你的代码？",
                en: "Where shall I look for your code?"
            ).text(lang)
        }
        static func directoriesHint(_ lang: Language = .zh) -> String {
            Loc(
                zh: "我会在这些目录里找所有 Git 仓库，\n会自动跳过 node_modules、vendor 等",
                en: "I'll find every Git repo inside,\nand skip node_modules, vendor, etc."
            ).text(lang)
        }
        static func directoriesAdd(_ lang: Language = .zh) -> String {
            Loc(zh: "+ 添加目录", en: "+ Add folder").text(lang)
        }
        static func directoriesEmpty(_ lang: Language = .zh) -> String {
            Loc(zh: "还没有选择目录", en: "No folders selected yet").text(lang)
        }
        static func directoriesSkip(_ lang: Language = .zh) -> String {
            Loc(zh: "跳过", en: "Skip").text(lang)
        }
        static func directoriesNext(_ lang: Language = .zh) -> String {
            Loc(zh: "继续", en: "Continue").text(lang)
        }

        static func privacyTitle(_ lang: Language = .zh) -> String {
            Loc(
                zh: "关于隐私，我想跟你说清楚",
                en: "About privacy — let me be upfront"
            ).text(lang)
        }
        static func privacyBody(_ lang: Language = .zh) -> String {
            Loc(
                zh: """
                ✅ 代码、commit、diff 都只在你的电脑上分析
                ✅ 不调用任何 LLM 或云端 API
                ✅ 唯一的网络行为是：
                   • 后台定期 git fetch（和你平时用 git 一样）
                   • 你主动触发的 git push
                   • 可选的 GitHub API 调用（仅检测仓库可见性）

                👀 想看 Pilo 做过什么？设置 → 关于 → 操作日志
                """,
                en: """
                ✅ Your code, commits, and diffs are analyzed only on your Mac
                ✅ No LLM calls, no cloud APIs
                ✅ The only network activity is:
                   • Background git fetch (same as plain git)
                   • git push when you choose to
                   • Optional GitHub API (only to detect repo visibility)

                👀 Want to see everything I've done? Settings → About → Activity log
                """
            ).text(lang)
        }
        static func privacyAck(_ lang: Language = .zh) -> String {
            Loc(zh: "我了解了", en: "Got it").text(lang)
        }

        static func completeTitleFound(_ lang: Language = .zh) -> String {
            Loc(zh: "找到了 %d 个仓库", en: "Found %d repos").text(lang)
        }
        static func completeTitleEmpty(_ lang: Language = .zh) -> String {
            Loc(zh: "暂时没找到仓库", en: "No repos here yet").text(lang)
        }
        static func completeGitInfo(_ lang: Language = .zh) -> String {
            Loc(zh: "Pilo 找到了 %@ 位于 %@", en: "Pilo found %@ at %@").text(lang)
        }
        static func completeNoGit(_ lang: Language = .zh) -> String {
            Loc(zh: "未找到 git 命令", en: "git not found").text(lang)
        }
        static func completeOpen(_ lang: Language = .zh) -> String {
            Loc(zh: "打开主面板", en: "Open main window").text(lang)
        }
        static func completeStayInMenubar(_ lang: Language = .zh) -> String {
            Loc(
                zh: "Pilo 会一直待在菜单栏 ↑",
                en: "I'll be up here in the menu bar ↑"
            ).text(lang)
        }

        // 保留旧静态属性供未迁移调用方使用
        static let welcomeTitle    = "咕咕～"
        static let welcomeBody     = "我是 Pilo，一只帮你安全送代码的小信鸽"
        static let welcomeFeature1 = "自动找到你电脑上的仓库"
        static let welcomeFeature2 = "push 前帮你查一遍敏感信息"
        static let welcomeFeature3 = "一切都在你电脑上做，代码不会离开本地"
        static let welcomeContinue = "继续"
        static let directoriesTitle = "告诉我去哪里找你的代码？"
        static let directoriesHint  = "我会在这些目录里找所有 Git 仓库，\n会自动跳过 node_modules、vendor 等"
        static let directoriesAdd   = "+ 添加目录"
        static let directoriesEmpty = "还没有选择目录"
        static let directoriesSkip  = "跳过"
        static let directoriesNext  = "继续"
        static let privacyTitle = "关于隐私，我想跟你说清楚"
        static let privacyBody  = """
        ✅ 代码、commit、diff 都只在你的电脑上分析
        ✅ 不调用任何 LLM 或云端 API
        ✅ 唯一的网络行为是：
           • 后台定期 git fetch（和你平时用 git 一样）
           • 你主动触发的 git push
           • 可选的 GitHub API 调用（仅检测仓库可见性）

        👀 想看 Pilo 做过什么？设置 → 关于 → 操作日志
        """
        static let privacyAck = "我了解了"
        static let completeTitleFound = "找到了 %d 个仓库"
        static let completeTitleEmpty = "暂时没找到仓库"
        static let completeGitInfo    = "Pilo 找到了 %@ 位于 %@"
        static let completeNoGit      = "未找到 git 命令"
        static let completeOpen       = "打开主面板"
        static let completeStayInMenubar = "Pilo 会一直待在菜单栏 ↑"
    }

    // MARK: - 推送（Phase 5）

    enum Push {

        // Preflight
        static func preflightTitle(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "准备寄出去啦", en: "Ready to send~").text(lang)
            case .minimal:
                return Loc(zh: "确认推送", en: "Confirm push").text(lang)
            }
        }
        static func preflightSubtitle(_ tone: Tone, _ lang: Language = .zh, count: Int) -> String {
            switch tone {
            case .friendly:
                return Loc(
                    zh: "我要把 \(count) 个 commit 寄到远端，没问题吧？",
                    en: "I'm sending \(count) commit\(count == 1 ? "" : "s") off — sound good?"
                ).text(lang)
            case .minimal:
                return Loc(
                    zh: "将推送 \(count) 个 commit",
                    en: "Pushing \(count) commit\(count == 1 ? "" : "s")"
                ).text(lang)
            }
        }

        static func preflightCommitsHeader(_ lang: Language = .zh) -> String {
            Loc(zh: "本次推送的 commit", en: "Commits to push").text(lang)
        }
        static func preflightFirstPushHint(_ lang: Language = .zh) -> String {
            Loc(
                zh: "首次推送 · 会自动设置 upstream（-u）",
                en: "First push · upstream will be set automatically (-u)"
            ).text(lang)
        }

        static func pushButton(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "✨ 寄出去", en: "✨ Send it").text(lang)
            case .minimal:
                return Loc(zh: "推送", en: "Push").text(lang)
            }
        }

        static func cancelButton(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "再想想", en: "Hold on").text(lang)
            case .minimal:
                return Loc(zh: "取消", en: "Cancel").text(lang)
            }
        }

        static func runningTitle(_ tone: Tone, _ lang: Language = .zh, remote: String) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "正在飞往 \(remote)...", en: "Off to \(remote)...").text(lang)
            case .minimal:
                return Loc(zh: "推送到 \(remote)...", en: "Pushing to \(remote)...").text(lang)
            }
        }

        // Completed - success
        static func successTitle(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "🌸 寄到啦！", en: "🌸 Delivered!").text(lang)
            case .minimal:
                return Loc(zh: "推送完成", en: "Push complete").text(lang)
            }
        }
        static func successSubtitle(_ tone: Tone, _ lang: Language = .zh, count: Int) -> String {
            switch tone {
            case .friendly:
                return Loc(
                    zh: "\(count) 个 commit 已经送到啦 ✨",
                    en: "\(count) commit\(count == 1 ? "" : "s") delivered ✨"
                ).text(lang)
            case .minimal:
                return Loc(
                    zh: "\(count) 个 commit 已送达",
                    en: "\(count) commit\(count == 1 ? "" : "s") sent"
                ).text(lang)
            }
        }

        // Push button entry (RepoDetailView)
        static func pushEntryButton(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(zh: "✨ 推送", en: "✨ Push").text(lang)
            case .minimal:
                return Loc(zh: "推送", en: "Push").text(lang)
            }
        }

        static func pushDisabledHint(_ lang: Language = .zh) -> String {
            Loc(zh: "没有可推送的 commit", en: "Nothing to push").text(lang)
        }

        // 保留旧静态属性供未迁移调用方
        static let preflightTitle = "准备推送啦"
        static let preflightCheckPassed = "✅ 安全检查全部通过"
        static let confirmPushButton = "✨ 推送 ✨"
        static let confirmCancelButton = "再想想"
        static let preflightCommitsHeader = "本次推送的 commit"
        static let preflightFirstPushHint = "首次推送 · 会自动设置 upstream（-u）"
        static let preflightScanPlaceholder = "🔒 安全检查（Phase 6 待启用）"
        static let confirmCheckPassed = "✅ 安全检查全部通过"
        static let pushDisabledHint = "没有可推送的 commit"

        // Phase 5 push error messages
        static let needSSHPassphrase = "需要你的 SSH key 密码"
        static let needCredentials = "需要登录凭证 · 请在终端先配置一次"
        static let needPAT = "GitHub 现在需要 Personal Access Token，不是密码"
        static let preHookFailed = "pre-push hook 拦下了这次推送："
        static let nonFastForward = "远端有新内容，需要先 pull 或 rebase"
        static let pushFailedGeneric = "咕咕没飞过去 🥲"
        static let retryButton = "再试一次"
        static let copyStderrButton  = "复制错误信息"
        static let openTerminalButton = "在终端打开"
        static let closeButton        = "关闭"
        static let doneButton         = "好啦"

        // failure title / explanation 暂保中文
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
            case (.success, _):                        ""
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
    }

    // MARK: - 安全扫描（Phase 6）— 关键提示保持温柔但坚定

    enum Scan {

        static func sectionHeader(_ tone: Tone, _ lang: Language = .zh, count: Int) -> String {
            switch (count, tone) {
            case (0, .friendly):
                return Loc(zh: "✅ 安全检查通过", en: "✅ All clear").text(lang)
            case (0, .minimal):
                return Loc(zh: "安全检查通过", en: "Clear").text(lang)
            case (_, .friendly):
                return Loc(
                    zh: "诶诶～发现 \(count) 处可能要看看",
                    en: "Hmm... \(count) thing\(count == 1 ? "" : "s") worth checking"
                ).text(lang)
            case (_, .minimal):
                return Loc(
                    zh: "发现 \(count) 处",
                    en: "\(count) finding\(count == 1 ? "" : "s")"
                ).text(lang)
            }
        }

        static func killSwitchSkipped(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                return Loc(
                    zh: "🕶️ 安全检查打盹儿中（紧急模式）",
                    en: "🕶️ Watch mode paused (emergency)"
                ).text(lang)
            case .minimal:
                return Loc(zh: "安全检查已暂停", en: "Scanner paused").text(lang)
            }
        }

        // 关键提示用语，所有都双语
        static func critical(_ lang: Language = .zh) -> String {
            Loc(zh: "高危", en: "Critical").text(lang)
        }
        static func warning(_ lang: Language = .zh) -> String {
            Loc(zh: "提示", en: "Notice").text(lang)
        }
        static func jumpToFile(_ lang: Language = .zh) -> String {
            Loc(zh: "在 Finder 中显示", en: "Show in Finder").text(lang)
        }
        static func markFP(_ lang: Language = .zh) -> String {
            Loc(zh: "标记为误报", en: "Mark safe").text(lang)
        }
        static func markFPHere(_ lang: Language = .zh) -> String {
            Loc(zh: "仅这个文件", en: "Just this file").text(lang)
        }
        static func markFPRule(_ lang: Language = .zh) -> String {
            Loc(zh: "整个仓库都不再扫这条规则",
                en: "Skip this rule for the whole repo").text(lang)
        }
        static func markFPCancel(_ lang: Language = .zh) -> String {
            Loc(zh: "再想想", en: "Hold on").text(lang)
        }
        static func markFPTitle(_ lang: Language = .zh) -> String {
            Loc(zh: "怎么标记？", en: "How to mark?").text(lang)
        }
        static func markFPSubtitle(_ lang: Language = .zh) -> String {
            Loc(zh: "下次扫描会按你选的范围跳过这一条。",
                en: "Next scan will skip this finding within the scope you pick.").text(lang)
        }

        static func pushBypassButton(_ lang: Language = .zh) -> String {
            Loc(zh: "我已了解，仍然推送", en: "I understand, push anyway").text(lang)
        }

        static func bypassConfirmTitle(_ lang: Language = .zh) -> String {
            Loc(zh: "🕊️ 真的吗？", en: "🕊️ Are you sure?").text(lang)
        }
        static func bypassConfirmDesc(_ lang: Language = .zh) -> String {
            Loc(
                zh: """
                推送之后这些 key 会进入 GitHub 历史，
                即使后续删除也很难真正清除。
                通常需要重新生成 key 才能彻底解决。

                📝 建议先做的事：
                  1. 在密钥服务商后台 revoke 这些 key
                  2. 重新生成新 key
                  3. 把新 key 放到 .env 而不是源码

                如果你坚持要推送，请输入仓库名确认：
                """,
                en: """
                Once pushed, these keys enter GitHub history.
                Even after deletion they're nearly impossible to truly scrub.
                Rotating the keys is usually the real fix.

                📝 What to do first:
                  1. Revoke these keys in their issuing dashboard
                  2. Generate fresh keys
                  3. Put the new keys in .env, not source

                If you still want to push, type the repo name to confirm:
                """
            ).text(lang)
        }
        static func bypassConfirmInputPlaceholder(_ lang: Language = .zh) -> String {
            Loc(zh: "在这里输入仓库名", en: "Type the repo name here").text(lang)
        }
        static func bypassConfirmYes(_ lang: Language = .zh) -> String {
            Loc(zh: "我已了解，推送", en: "I understand, push").text(lang)
        }
        static func bypassConfirmNo(_ lang: Language = .zh) -> String {
            Loc(zh: "取消", en: "Cancel").text(lang)
        }
        static func bypassNameMismatch(_ lang: Language = .zh) -> String {
            Loc(zh: "仓库名不匹配", en: "Repo name doesn't match").text(lang)
        }

        // 旧静态属性保留供未迁移调用方
        static let critical    = "高危"
        static let warning     = "提示"
        static let jumpToFile  = "在 Finder 中显示"
        static let markFP      = "标记为误报"
        static let markFPHere  = "仅这个文件"
        static let markFPRule  = "整个仓库都不再扫这条规则"
        static let markFPCancel = "再想想"
        static let markFPTitle = "怎么标记？"
        static let markFPSubtitle = "下次扫描会按你选的范围跳过这一条。"
        static let pushBypassButton = "我已了解，仍然推送"
        static let bypassConfirmTitle = "🕊️ 真的吗？"
        static let bypassConfirmDesc = "推送之后这些 key 会进入 GitHub 历史…"
        static let bypassConfirmInputPlaceholder = "在这里输入仓库名"
        static let bypassConfirmYes = "我已了解，推送"
        static let bypassConfirmNo  = "取消"
        static let bypassNameMismatch = "仓库名不匹配"
    }

    // MARK: - Kill switch（Phase 6）— 设置 UI 文案

    enum KillSwitch {

        static func bannerInMenuBar(_ tone: Tone, _ lang: Language = .zh, remainingHours: Int) -> String {
            switch tone {
            case .friendly:
                return Loc(
                    zh: "🕶️ 安全检查暂停中（\(remainingHours) 小时后自动醒）· 点击立即叫醒",
                    en: "🕶️ Watch mode paused (\(remainingHours)h to auto-wake) · tap to wake now"
                ).text(lang)
            case .minimal:
                return Loc(
                    zh: "安全检查已关闭（\(remainingHours) 小时后恢复）· 立即恢复",
                    en: "Scanner off (\(remainingHours)h to restore) · restore now"
                ).text(lang)
            }
        }

        // 设置页 UI 文案 — 全部双语
        static func settingsSectionTitle(_ lang: Language = .zh) -> String {
            Loc(zh: "安全检查", en: "Security checks").text(lang)
        }
        static func settingsToggleDescription(_ lang: Language = .zh) -> String {
            Loc(
                zh: "推送前扫描 diff，发现 API key / token / 私钥等。规则集来自 Pilo 内置的 25 条精挑模板，纯本地匹配。",
                en: "Scans the diff before pushing for API keys / tokens / private keys. Uses Pilo's 25 hand-picked rules, fully local — nothing leaves your Mac."
            ).text(lang)
        }
        static func settingsKillSwitchTitle(_ lang: Language = .zh) -> String {
            Loc(zh: "紧急关闭安全检查", en: "Emergency: turn off scans").text(lang)
        }
        static func settingsKillSwitchDesc(_ lang: Language = .zh) -> String {
            Loc(
                zh: "暂时关闭所有安全扫描，让 push 可以无阻通过。24 小时后自动恢复——避免你忘了自己关过。",
                en: "Pause every security scan so push goes through unhindered. Auto-restores in 24 hours — so you won't forget you turned it off."
            ).text(lang)
        }
        static func settingsKillSwitchActivateButton(_ lang: Language = .zh) -> String {
            Loc(zh: "暂时关闭 24 小时", en: "Pause for 24 hours").text(lang)
        }
        static func settingsKillSwitchActiveLabel(_ lang: Language = .zh) -> String {
            Loc(zh: "已关闭，%d 小时后恢复", en: "Off — restores in %d hour(s)").text(lang)
        }
        static func settingsKillSwitchRestoreButton(_ lang: Language = .zh) -> String {
            Loc(zh: "立即恢复", en: "Restore now").text(lang)
        }

        // 旧静态属性保留
        static let settingsSectionTitle = "安全检查"
        static let settingsToggleEnabled  = "启用敏感信息扫描"
        static let settingsToggleDescription = "推送前扫描 diff，发现 API key / token / 私钥等。规则集来自 Pilo 内置的 25 条精挑模板，纯本地匹配。"
        static let settingsKillSwitchTitle = "紧急关闭安全检查"
        static let settingsKillSwitchDesc  = "暂时关闭所有安全扫描，让 push 可以无阻通过。24 小时后自动恢复——避免你忘了自己关过。"
        static let settingsKillSwitchActivateButton = "暂时关闭 24 小时"
        static let settingsKillSwitchActiveLabel  = "已关闭，%d 小时后恢复"
        static let settingsKillSwitchRestoreButton = "立即恢复"
    }

    // MARK: - 误提交防护（Phase 7）

    enum Guard {
        static let criticalGroupTitle = "高危 · 阻断推送"
        static let warningGroupTitle  = "提示 · 可以推但建议处理"

        static func summaryAllClear(_ tone: Tone) -> [String] {
            switch tone {
            case .friendly:
                return ["✅ 没有发现敏感信息", "✅ 没有可疑文件", "✅ 文件大小都正常"]
            case .minimal:
                return ["敏感信息扫描通过", "文件类型检查通过", "文件大小检查通过"]
            }
        }

        static let addToGitignoreButton = "加入 .gitignore"
        static let showInFinderButton   = "在 Finder 中显示"
        static let learnLFSButton       = "了解 Git LFS"
        static let ignoreOnceButton     = "仅本次忽略"
        static let markSafeButton       = "已确认安全"
        static let jumpToCodeButton     = "跳转到代码"
        static let actionSheetTitle = "已加入 .gitignore"
        static let actionSheetOpen  = "用编辑器打开 .gitignore"
        static let actionSheetCopyFilterCmd = "复制 filter-repo 命令"
        static let actionSheetDone  = "知道了"

        static func pushDisabledByCritical(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "处理高危项后才能推送"
            case .minimal:  "请先处理高危项"
            }
        }
        static func pushBypassLink(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "了解风险，仍然推送 →"
            case .minimal:  "强制推送 →"
            }
        }
        static func sectionTitle(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "🛡️ 推送前检查"
            case .minimal:  "推送前检查"
            }
        }
        static func sectionSummaryClear(_ tone: Tone) -> String {
            switch tone {
            case .friendly: "全部通过 ✨"
            case .minimal:  "通过"
            }
        }
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

    // MARK: - Phase B: Project Inventory

    enum Inventory {

        // Sidebar 三段标题（活跃 / 静默 / 沉寂）
        static func sidebarActive(_ lang: Language) -> String {
            lang == .zh ? "活跃" : "Active"
        }
        static func sidebarIdle(_ lang: Language) -> String {
            lang == .zh ? "静默" : "Idle"
        }
        static func sidebarDormant(_ lang: Language) -> String {
            lang == .zh ? "沉寂" : "Dormant"
        }

        // Mood label（用在 health row / a11y / mood chip）
        static func moodLabel(_ mood: RepoMood, _ lang: Language) -> String {
            switch (mood, lang) {
            case (.active, .zh):    return "活跃"
            case (.active, .en):    return "Active"
            case (.idle, .zh):      return "静默"
            case (.idle, .en):      return "Idle"
            case (.dying, .zh):     return "渐凉"
            case (.dying, .en):     return "Dying"
            case (.abandoned, .zh): return "搁置"
            case (.abandoned, .en): return "Abandoned"
            }
        }

        // Category label（信件上的分拣戳）
        static func categoryLabel(_ cat: RepoCategory, _ lang: Language) -> String {
            switch (cat, lang) {
            case (.work, .zh):        return "工作"
            case (.work, .en):        return "Work"
            case (.personal, .zh):    return "个人"
            case (.personal, .en):    return "Personal"
            case (.experiment, .zh):  return "实验"
            case (.experiment, .en):  return "Experiment"
            case (.unset, .zh):       return "未分类"
            case (.unset, .en):       return "Unsorted"
            }
        }

        // Category 单字符印章（贴在 repo row 上的小标记，节省空间）
        static func categoryStamp(_ cat: RepoCategory, _ lang: Language) -> String {
            switch cat {
            case .work:        return lang == .zh ? "工" : "W"
            case .personal:    return lang == .zh ? "私" : "P"
            case .experiment:  return lang == .zh ? "试" : "E"
            case .unset:       return ""
            }
        }

        // 健康信号 pills
        static func missingReadme(_ lang: Language) -> String {
            lang == .zh ? "缺 README" : "No README"
        }
        static func missingTests(_ lang: Language) -> String {
            lang == .zh ? "无测试" : "No tests"
        }

        /// "N 天没动了"
        static func dormantDays(days: Int, _ lang: Language) -> String {
            if lang == .zh {
                return "\(days) 天没动了"
            } else {
                return days == 1 ? "1 day idle" : "\(days) days idle"
            }
        }

        // 详情面板 abandoned 提醒卡
        static func abandonedTitle(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "这个仓库睡了好久了"
            case (.friendly, .en): return "This one's been sleeping for a while"
            case (.minimal, .zh):  return "已闲置 90+ 天"
            case (.minimal, .en):  return "Inactive for 90+ days"
            }
        }
        static func abandonedBody(_ tone: Tone, _ lang: Language, days: Int) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "已经 \(days) 天没动它了。要不要给它一个去处？"
            case (.friendly, .en): return "Untouched for \(days) days. Want to give it a home?"
            case (.minimal, .zh):  return "最后改动 \(days) 天前"
            case (.minimal, .en):  return "Last activity \(days) days ago"
            }
        }
        static func abandonedActionKeep(_ lang: Language) -> String {
            lang == .zh ? "继续保留" : "Keep it"
        }
        static func abandonedActionHide(_ lang: Language) -> String {
            lang == .zh ? "藏起来不再提醒" : "Hide from list"
        }
        static func abandonedActionOpenFinder(_ lang: Language) -> String {
            lang == .zh ? "在 Finder 里打开" : "Show in Finder"
        }

        // Category picker 提示
        static func categoryPickerPrompt(_ lang: Language) -> String {
            lang == .zh ? "贴上一枚邮戳" : "Stamp it"
        }
        static func categoryPickerUnset(_ lang: Language) -> String {
            lang == .zh ? "撕掉邮戳" : "Remove stamp"
        }

        // Health row 标题（详情面板那行 chips 上方的小 label）
        static func healthRowLabel(_ lang: Language) -> String {
            lang == .zh ? "项目体检" : "Project health"
        }
    }

    // MARK: - Resume Work（上次做到哪）

    enum Resume {

        /// 卡片主标题。首次见面（lastViewedDate == nil）用不同问候。
        static func title(firstTime: Bool, _ tone: Tone, _ lang: Language) -> String {
            if firstTime {
                switch (tone, lang) {
                case (.friendly, .zh): return "初次见面"
                case (.friendly, .en): return "Nice to meet you"
                case (.minimal, .zh):  return "新仓库"
                case (.minimal, .en):  return "New repo"
                }
            } else {
                switch (tone, lang) {
                case (.friendly, .zh): return "欢迎回来"
                case (.friendly, .en): return "Welcome back"
                case (.minimal, .zh):  return "继续工作"
                case (.minimal, .en):  return "Resume"
                }
            }
        }

        /// 副标题："上次见你 X 天前 · 在 branch Y"。
        /// 时间用 RelativeDateTimeFormatter localized，branch 末尾追加（仅有 branch 才显示）。
        static func subtitle(daysSinceViewed: Int?, branch: String?, _ lang: Language) -> String {
            var parts: [String] = []
            if let days = daysSinceViewed {
                if lang == .zh {
                    if days == 0 {
                        parts.append("今天刚见过")
                    } else if days == 1 {
                        parts.append("上次是昨天")
                    } else {
                        parts.append("上次见你是 \(days) 天前")
                    }
                } else {
                    if days == 0 {
                        parts.append("Saw you earlier today")
                    } else if days == 1 {
                        parts.append("Last seen yesterday")
                    } else {
                        parts.append("Last seen \(days) days ago")
                    }
                }
            }
            if let b = branch {
                parts.append(lang == .zh ? "在 \(b)" : "on \(b)")
            }
            return parts.joined(separator: " · ")
        }

        // Section labels（卡片内部）
        static func draftsLabel(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "— 留下的草稿 · \(count) —" }
            return count == 1 ? "— 1 draft left behind —" : "— \(count) drafts left behind —"
        }
        static func recentSentLabel(_ lang: Language) -> String {
            lang == .zh ? "— 最近寄出 —" : "— recently sent —"
        }

        // 未提交文件 status 单字符标记（mono 字体显示）
        static func statusBadge(_ status: UncommittedFile.Status) -> String {
            switch status {
            case .modified:   return "M"
            case .added:      return "A"
            case .deleted:    return "D"
            case .renamed:    return "R"
            case .copied:     return "C"
            case .untracked:  return "?"
            case .conflicted: return "!"
            case .other:      return "·"
            }
        }
    }

    // MARK: - 项目文档面板

    enum Docs {
        static func sectionTitle(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "项目文档 · \(count) 份" }
            return count == 1 ? "Project docs · 1" : "Project docs · \(count)"
        }
        static func empty(_ lang: Language) -> String {
            lang == .zh ? "这个项目还没什么文档" : "No docs in this project yet"
        }
        /// 文件 mtime 的人类可读相对时间（"3 天前" / "2 周前"）
        static func relativeModified(_ date: Date, _ lang: Language) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.locale = (lang == .zh) ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        static func rowHint(_ lang: Language) -> String {
            lang == .zh ? "点开看看 · ↗ 用编辑器打开" : "Click to read · ↗ open in editor"
        }
        static func expandAll(more: Int, _ lang: Language) -> String {
            lang == .zh ? "展开全部 \(more) 份更多" : "Show all · \(more) more"
        }
        static func collapseToTop(_ top: Int, _ lang: Language) -> String {
            lang == .zh ? "收起，只看前 \(top) 份" : "Collapse to top \(top)"
        }

        // 隐藏 / 取消隐藏（右键 menu + footer）
        static func hideAction(_ lang: Language) -> String {
            lang == .zh ? "藏起来不再显示" : "Hide from this list"
        }
        static func unhideAction(_ lang: Language) -> String {
            lang == .zh ? "翻出来" : "Bring back"
        }
        static func showInFinder(_ lang: Language) -> String {
            lang == .zh ? "在 Finder 显示" : "Show in Finder"
        }
        static func hiddenSectionHeader(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "已藏起 \(count) 份" }
            return count == 1 ? "1 hidden" : "\(count) hidden"
        }
        static func hiddenSectionToggleShow(_ lang: Language) -> String {
            lang == .zh ? "翻出来看看" : "Peek inside"
        }
        static func hiddenSectionToggleHide(_ lang: Language) -> String {
            lang == .zh ? "收起" : "Tuck away"
        }
        static func moreActions(_ lang: Language) -> String {
            lang == .zh ? "更多操作" : "More actions"
        }
    }

    // MARK: - Markdown 预览 sheet

    enum Preview {
        static func openInEditor(_ lang: Language) -> String {
            lang == .zh ? "用编辑器打开" : "Open in editor"
        }
        static func close(_ lang: Language) -> String {
            lang == .zh ? "关闭" : "Close"
        }
        static func loading(_ lang: Language) -> String {
            lang == .zh ? "正在翻开这封信..." : "Opening the letter..."
        }

        // 错误态
        static func errorTooLargeTitle(_ lang: Language) -> String {
            lang == .zh ? "这份文档太长了" : "This document is too long"
        }
        static func errorTooLargeBody(_ lang: Language) -> String {
            lang == .zh
                ? "为了不卡顿，Pilo 不在邮局内展示超过 500 KB 的文档。\n请用编辑器打开看完整内容。"
                : "To stay snappy, Pilo doesn't inline docs over 500 KB.\nPlease open it in your editor for the full read."
        }
        static func errorNotTextTitle(_ lang: Language) -> String {
            lang == .zh ? "这不是一份文本文档" : "Not a text document"
        }
        static func errorNotTextBody(_ lang: Language) -> String {
            lang == .zh
                ? "Pilo 只能展示 UTF-8 文本，遇到二进制或其他编码就读不出来了。"
                : "Pilo can only render UTF-8 text. This file looks binary or in another encoding."
        }
        static func errorNotFoundTitle(_ lang: Language) -> String {
            lang == .zh ? "文件找不到了" : "File not found"
        }
        static func errorNotFoundBody(_ lang: Language) -> String {
            lang == .zh ? "刚才还在的，可能被移走或重命名了。" : "It was here a moment ago. Maybe moved or renamed."
        }
        static func errorEmptyTitle(_ lang: Language) -> String {
            lang == .zh ? "这份文档是空的" : "This document is empty"
        }
        static func errorEmptyBody(_ lang: Language) -> String {
            lang == .zh ? "里面什么都没有，是占位文件。" : "Nothing inside. Looks like a placeholder."
        }
    }
}
