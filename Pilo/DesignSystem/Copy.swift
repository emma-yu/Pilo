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
            // 精简：从 "我要把 N 个 commit 寄到远端，没问题吧？" 缩短
            // 信息密度提升，问句感留在按钮 "寄出去" 上
            switch tone {
            case .friendly:
                return Loc(
                    zh: "准备把 \(count) 个 commit 寄到远端",
                    en: "About to send \(count) commit\(count == 1 ? "" : "s")"
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
            // 去掉 ✨ —— 邮局动作是 paperplane / envelope，不是魔法。
            // 按钮 icon 在 view 里加 paperplane.fill SF
            switch tone {
            case .friendly:
                return Loc(zh: "寄出去", en: "Send it").text(lang)
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

        // Loading 态（拉 diff / 安全扫描中）
        static func loadingTitle(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "正在准备推送..."
            case (.friendly, .en): return "Getting things ready..."
            case (.minimal, .zh):  return "准备中"
            case (.minimal, .en):  return "Preparing"
            }
        }
        static func loadingSubtitle(_ lang: Language, repoName: String) -> String {
            lang == .zh
                ? "Pilo 在帮你检查 \(repoName) 这次要寄出的内容\n（拉 commit 列表 · 扫敏感信息 · 看大文件）"
                : "Pilo is checking what \(repoName) is about to send\n(commit list · secret scan · large files)"
        }

        // Completed - success
        static func successTitle(_ tone: Tone, _ lang: Language = .zh) -> String {
            switch tone {
            case .friendly:
                // 不带 emoji —— P 蜡封 + 信件堆叠的视觉已经承担了"完成感"
                return Loc(zh: "寄到啦！", en: "Delivered!").text(lang)
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

        // History 脱钩 / force-with-lease 覆盖
        static func forcePushButton(_ lang: Language) -> String {
            lang == .zh ? "覆盖远程历史" : "Force push (overwrite remote)"
        }
        static func forcePushConfirmTitle(_ lang: Language) -> String {
            lang == .zh ? "确认覆盖远程？" : "Overwrite remote?"
        }
        static func forcePushConfirmBody(_ lang: Language) -> String {
            lang == .zh
                ? "Pilo 会用 --force-with-lease：如果远程被别人 push 过会安全失败，不会盲覆盖。\n这一步不可撤销，确认吗？"
                : "Pilo will use --force-with-lease: if someone else has pushed to the remote, it'll safely fail rather than blindly overwrite.\nThis cannot be undone — confirm?"
        }
        static func forcePushConfirmYes(_ lang: Language) -> String {
            lang == .zh ? "确认覆盖" : "Yes, overwrite"
        }
        static func forcePushConfirmNo(_ lang: Language) -> String {
            lang == .zh ? "再想想" : "Cancel"
        }
        static let doneButton         = "好啦"

        // failure title / explanation 暂保中文
        static func failureTitle(_ tone: Tone, outcome: PushOutcome) -> String {
            switch (outcome, tone) {
            case (.authenticationFailed, .friendly):  "🥲 没认证通过"
            case (.authenticationFailed, .minimal):   "认证失败"
            case (.nonFastForward(_, true), .friendly): "🪶 本地历史跟远程脱钩了"
            case (.nonFastForward(_, true), .minimal):  "History 脱钩"
            case (.nonFastForward(_, false), .friendly): "😯 远端有新内容"
            case (.nonFastForward(_, false), .minimal):  "Non-fast-forward"
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
            case .nonFastForward(_, true):
                """
                你重写过本地 history（filter-repo / rebase / commit --amend），现在跟远程没有共同祖先了。

                ⚠️ 不能 pull —— 那会把远程的旧 commits 拉回来，污染你刚理干净的本地 history。

                正确做法：用 force push 覆盖远程。Pilo 用的是 --force-with-lease，
                如果远程被别人 push 过会安全失败而不会覆盖。
                """
            case .nonFastForward(_, false):
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
            // 不要 ✅ emoji —— UI 里已有 checkmark.circle.fill SF 复选圆作为视觉标记
            // 在文本里再加 emoji 是同语义重复 + 跟 Pilo Songti 美学冲突
            switch tone {
            case .friendly:
                return ["没有发现敏感信息", "没有可疑文件", "文件大小都正常"]
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
            // 不要 emoji 🛡️ —— SF 盾牌 icon 在 view 里已经存在
            switch tone {
            case .friendly: "推送前检查"
            case .minimal:  "推送前检查"
            }
        }
        static func sectionSummaryClear(_ tone: Tone) -> String {
            // 不要 ✨ —— 邮局美学不用 emoji 装饰
            switch tone {
            case .friendly: "全部通过"
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

        /// 副标题：智能 contextual。按 4 档优先级 fallback：
        ///   P1 有 work → actionable："桌上还有 N 件没封口 · M 个等着寄出"
        ///   P2 1-29 天没见 → 时间感："上次见你是 N 天前"
        ///   P3 30+ 天没见 → 长别离 flavor："已经 N 天没见，欢迎回来"
        ///   P4 都没有 → "在 main · 一切都好"
        ///
        /// 旧版总是输出 "今天见过 · 在 main" —— tautology + 重复上面 path 行
        /// 现在永远 dynamic，每次回来副标题都讲一个新故事
        static func subtitle(
            uncommittedCount: Int,
            pendingPushCount: Int,
            daysSinceViewed: Int?,
            branch: String?,
            _ tone: Tone,
            _ lang: Language
        ) -> String {
            // P1 actionable —— 用户最关心的：现在能做什么
            if uncommittedCount > 0 || pendingPushCount > 0 {
                return actionableSubtitle(
                    uncommitted: uncommittedCount,
                    pending: pendingPushCount,
                    tone: tone,
                    lang: lang
                )
            }

            // P2 / P3 时间感（没 work，但有上次见过的时间）
            if let days = daysSinceViewed {
                if days >= 30 {
                    return longAbsenceSubtitle(days: days, tone: tone, lang: lang)
                }
                if days >= 1 {
                    return recentAbsenceSubtitle(days: days, lang: lang)
                }
                // days == 0 + no work → fall through to P4 (避免说"今天见过"的 tautology)
            }

            // P4 fallback —— cleanup 完一切都好；branch 在这里有意义（其它档已不再重复 branch）
            return cleanStateSubtitle(branch: branch, tone: tone, lang: lang)
        }

        /// P1 actionable
        private static func actionableSubtitle(uncommitted: Int, pending: Int, tone: Tone, lang: Language) -> String {
            switch (uncommitted > 0, pending > 0) {
            case (true, true):
                return lang == .zh
                    ? "桌上 \(uncommitted) 件 · 待寄 \(pending) 个"
                    : "\(uncommitted) draft\(uncommitted == 1 ? "" : "s") · \(pending) to send"
            case (true, false):
                if lang == .zh {
                    return tone == .friendly
                        ? "桌上还有 \(uncommitted) 件没封口"
                        : "\(uncommitted) 个未提交"
                }
                return uncommitted == 1
                    ? "1 draft on the desk"
                    : "\(uncommitted) drafts on the desk"
            case (false, true):
                if lang == .zh {
                    return tone == .friendly
                        ? "\(pending) 个 commit 等着寄出"
                        : "\(pending) 个待推送"
                }
                return pending == 1
                    ? "1 commit to send"
                    : "\(pending) commits to send"
            case (false, false):
                return ""   // 不会走到，前面已 guard
            }
        }

        /// P2 1-29 天
        private static func recentAbsenceSubtitle(days: Int, lang: Language) -> String {
            if lang == .zh {
                if days == 1 { return "昨天来过" }
                return "上次见你是 \(days) 天前"
            }
            if days == 1 { return "Last seen yesterday" }
            return "Last seen \(days) days ago"
        }

        /// P3 30+ 天
        private static func longAbsenceSubtitle(days: Int, tone: Tone, lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "已经 \(days) 天没见，欢迎回来"
            case (.friendly, .en): return "\(days) days since we last met — welcome back"
            case (.minimal, .zh):  return "\(days) 天没见"
            case (.minimal, .en):  return "Last seen \(days) days ago"
            }
        }

        /// P4 cleanup 完一切都好
        private static func cleanStateSubtitle(branch: String?, tone: Tone, lang: Language) -> String {
            let b = branch ?? ""
            switch (tone, lang) {
            case (.friendly, .zh):
                return b.isEmpty ? "一切都好" : "在 \(b) · 一切都好"
            case (.friendly, .en):
                return b.isEmpty ? "All clear" : "on \(b) · all clear"
            case (.minimal, .zh):
                return b.isEmpty ? "已同步" : "\(b) · 已同步"
            case (.minimal, .en):
                return b.isEmpty ? "In sync" : "\(b) · in sync"
            }
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
            // < 60s 强制"刚刚"，避免系统给出"0 seconds ago"这种笨拙文案
            let elapsed = Date().timeIntervalSince(date)
            if elapsed >= 0 && elapsed < 60 {
                return lang == .zh ? "刚刚" : "just now"
            }
            let formatter = RelativeDateTimeFormatter()
            // 紧凑显示：行尾空间小，".short" → "2h ago" / "2小时前"，比 ".full" 紧凑一半
            formatter.unitsStyle = .short
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

        // 隐藏 / 取消隐藏（右键 menu + footer）—— 邮局意象：把信收进抽屉、再投递
        static func hideAction(_ lang: Language) -> String {
            lang == .zh ? "收进抽屉" : "Set aside"
        }
        static func unhideAction(_ lang: Language) -> String {
            // 对仗"收进抽屉" — 邮局柜员把信从抽屉里取回到桌面上。
            // 英文保持 "Bring back"（短 + idiomatic）。
            lang == .zh ? "放回桌面" : "Bring back"
        }
        static func showInFinder(_ lang: Language) -> String {
            lang == .zh ? "在 Finder 显示" : "Show in Finder"
        }
        static func hiddenSectionHeader(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "抽屉里还有 \(count) 封" }
            return count == 1 ? "1 letter set aside" : "\(count) letters set aside"
        }
        static func hiddenSectionToggleShow(_ lang: Language) -> String {
            lang == .zh ? "打开抽屉" : "Open the drawer"
        }
        static func hiddenSectionToggleHide(_ lang: Language) -> String {
            lang == .zh ? "盖上抽屉" : "Close the drawer"
        }
        /// 行内 hover 时露出的"收进抽屉"按钮 tooltip（不显示文字，只用 icon）
        static func setAsideHint(_ lang: Language) -> String {
            lang == .zh ? "收进抽屉" : "Set aside"
        }
        /// HiddenDocRow 左侧的"暂搁"小邮戳
        static func setAsideStamp(_ lang: Language) -> String {
            lang == .zh ? "暂搁" : "PAUSED"
        }
        /// MarkdownPreviewSheet 左侧 TOC sidebar 顶部 label
        static func tocTitle(_ lang: Language) -> String {
            lang == .zh ? "目 录" : "CONTENTS"
        }
        /// MarkdownPreviewSheet toolbar TOC toggle 按钮 tooltip
        static func tocToggle(expanded: Bool, _ lang: Language) -> String {
            switch (expanded, lang) {
            case (true, .zh):  return "折起目录"
            case (true, .en):  return "Hide contents"
            case (false, .zh): return "翻开目录"
            case (false, .en): return "Show contents"
            }
        }
        /// MarkdownPreviewSheet ⌘F 搜索 placeholder（提前加好供 Phase 4 用）
        static func searchPlaceholder(_ lang: Language) -> String {
            lang == .zh ? "搜全文…" : "Search in document…"
        }
        /// 搜索结果计数 "3/12"，统一格式化（适配未来本地化）
        static func searchCount(current: Int, total: Int, _ lang: Language) -> String {
            "\(current)/\(total)"
        }
        /// 无匹配时小灰字
        static func searchNoMatch(_ lang: Language) -> String {
            lang == .zh ? "找不到" : "No matches"
        }
    }

    // MARK: - 每日邮局信件

    enum Letter {
        // PanelHeader 信箱入口 pill
        static func inboxLabel(_ lang: Language) -> String {
            lang == .zh ? "信箱" : "Inbox"
        }
        static func inboxTooltip(unread: Int, _ lang: Language) -> String {
            if unread > 0 {
                return lang == .zh ? "邮箱里有 \(unread) 封未读" : "\(unread) unread in your inbox"
            }
            return lang == .zh ? "查看过往信件" : "Browse past letters"
        }

        // Archive sheet
        static func archiveTitle(_ lang: Language) -> String {
            lang == .zh ? "信箱" : "Letter Inbox"
        }
        static func archiveSubtitle(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            // 不写"18:00"这种工程数字——保留邮局诗意；用"傍晚"传达"下班时分"的感觉
            case (.friendly, .zh): return "傍晚有一封小信飞来"
            case (.friendly, .en): return "An evening letter, every day"
            case (.minimal, .zh):  return "每日投递"
            case (.minimal, .en):  return "Daily delivery"
            }
        }
        static func archiveEmpty(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "信箱还是空的\n等傍晚第一封信飞来"
            case (.friendly, .en): return "Your inbox is empty\nThe first letter will arrive this evening"
            case (.minimal, .zh):  return "暂无信件"
            case (.minimal, .en):  return "No letters yet"
            }
        }
        static func unreadBadge(_ lang: Language) -> String {
            lang == .zh ? "未读" : "Unread"
        }

        // MARK: - 版本通告信（ReleaseLetter）

        /// 信箱行的标题前缀，如 "v0.4 · 邮局通告"
        static func releaseRowHeader(version: String, _ lang: Language) -> String {
            lang == .zh ? "v\(version) · 邮局通告" : "v\(version) · From Pilo HQ"
        }

        /// Reader 标题
        static func releaseLetterHeader(_ lang: Language) -> String {
            lang == .zh ? "邮局通告" : "From the Post Office"
        }

        /// Reader 落款
        static func releaseLetterSignature(_ lang: Language) -> String {
            lang == .zh ? "Pilo 邮局总局" : "— Pilo HQ"
        }

        /// Reader 中"亮点 / Highlights" section 标题
        static func releaseHighlightsLabel(_ lang: Language) -> String {
            lang == .zh ? "— 这次寄了什么 —" : "— What's in this letter —"
        }

        // MARK: - 「新版本已发车」UpdateAvailableLetter

        /// 信箱行 header，"v0.5 · 新版已发车"
        static func updateRowHeader(version: String, _ lang: Language) -> String {
            lang == .zh ? "v\(version) · 新版已发车" : "v\(version) · New version available"
        }
        /// Reader 大标题
        static func updateLetterHeader(_ lang: Language) -> String {
            lang == .zh ? "邮局新车已发" : "A new version has shipped"
        }
        /// 「下载新版本」主 CTA
        static func updateDownloadCTA(_ lang: Language) -> String {
            lang == .zh ? "下载新版本" : "Download new version"
        }
        /// 「在浏览器看完整 release notes」次要 CTA
        static func updateViewNotesCTA(_ lang: Language) -> String {
            lang == .zh ? "查看完整 release notes" : "Read full release notes"
        }
        /// 「以后再说」dismiss
        static func updateDismissCTA(_ lang: Language) -> String {
            lang == .zh ? "以后再说" : "Maybe later"
        }

        // Reader letter content
        static func letterHeader(_ lang: Language) -> String {
            lang == .zh ? "今日工作总结" : "Today's Summary"
        }
        /// 收信人称呼：name 非 nil 用名字；nil/空 → fallback "朋友" / "friend"
        static func greeting(name: String?, _ lang: Language) -> String {
            let safe = name?.trimmingCharacters(in: .whitespaces) ?? ""
            if safe.isEmpty {
                return lang == .zh ? "亲爱的朋友，" : "Dear friend,"
            }
            return lang == .zh ? "亲爱的 \(safe)，" : "Dear \(safe),"
        }
        static func openingLine(_ lang: Language) -> String {
            lang == .zh ? "今天你完成了：" : "Today you finished:"
        }
        static func remoteLabel(remote: String, _ lang: Language) -> String {
            lang == .zh ? "已寄出 \(remote)" : "sent to \(remote)"
        }
        static func notPushedLabel(_ lang: Language) -> String {
            lang == .zh ? "桌上还没寄" : "still on the desk"
        }
        static func moreCommits(_ count: Int, _ lang: Language) -> String {
            lang == .zh ? "……还有 \(count) 个" : "…and \(count) more"
        }
        static func draftsHeader(_ lang: Language) -> String {
            lang == .zh ? "桌上还有：" : "Still on the desk:"
        }
        static func draftCount(_ count: Int, _ lang: Language) -> String {
            lang == .zh ? "\(count) 个未提交" : "\(count) uncommitted"
        }

        /// 「今日邮局合作社」section 标题 —— AI 协作日志
        static func aiCompanionsHeader(_ lang: Language) -> String {
            lang == .zh ? "今日邮局合作社" : "Today's postal partners"
        }
        /// 单个 AI 工具的活动量描述 —— 不同工具单位不同（项目 / 工作区 / 次）
        static func aiCompanionUnit(count: Int, tool: AITool, _ lang: Language) -> String {
            // 每种 tool 选合适的中文量词
            let unitZH: String
            let unitEN: String
            switch tool {
            case .claudeCode:
                unitZH = "个对话"; unitEN = count == 1 ? "conversation" : "conversations"
            case .cursor, .windsurf:
                unitZH = "个工作区"; unitEN = count == 1 ? "workspace" : "workspaces"
            case .aider:
                unitZH = "个项目"; unitEN = count == 1 ? "project" : "projects"
            case .codex, .gemini, .vscode:
                unitZH = "次"; unitEN = count == 1 ? "session" : "sessions"
            }
            return lang == .zh ? "\(count) \(unitZH)" : "\(count) \(unitEN)"
        }
        /// 合作社 section 底部小结
        static func aiCompanionsFooter(totalCount: Int, toolCount: Int, _ lang: Language) -> String {
            if lang == .zh {
                return "共 \(totalCount) 次跨 \(toolCount) 个工具"
            }
            return "\(totalCount) total across \(toolCount) tool\(toolCount == 1 ? "" : "s")"
        }
        static func totalLine(commits: Int, repos: Int, _ lang: Language) -> String {
            if lang == .zh {
                return "今日累计 \(commits) 个 commit · \(repos) 个仓库"
            }
            return "\(commits) commit\(commits == 1 ? "" : "s") · \(repos) repo\(repos == 1 ? "" : "s") today"
        }
        /// 行数变化简短表达：+120 / -45
        static func lineChangeBadge(added: Int, removed: Int) -> String {
            "+\(added) / -\(removed)"
        }
        /// 工作时段：09:30 - 17:45
        static func workSpanLine(first: Date, last: Date, hours: Double, _ lang: Language) -> String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            let fs = f.string(from: first)
            let ls = f.string(from: last)
            let h = String(format: "%.1f", hours)
            if lang == .zh {
                return "工作时段 \(fs) – \(ls) · 约 \(h) 小时"
            }
            return "Work span \(fs) – \(ls) · about \(h)h"
        }
        /// 草稿仓库的"还有 N 个改动"小字
        static func draftFilesMore(count: Int, _ lang: Language) -> String {
            lang == .zh ? "……还有 \(count) 个改动" : "…and \(count) more"
        }
        static func closingLine(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "明天见，"
            case (.friendly, .en): return "See you tomorrow,"
            case (.minimal, .zh):  return "—"
            case (.minimal, .en):  return "—"
            }
        }
        static func signature(_ lang: Language) -> String {
            lang == .zh ? "Pilo" : "Pilo"
        }
        static func emptyLetterBody(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "今天好像没什么活动\n如果你正在休息，也很好"
            case (.friendly, .en): return "Quiet day, nothing to report\nIf you're resting, that's also good"
            case (.minimal, .zh):  return "今日无活动"
            case (.minimal, .en):  return "No activity today"
            }
        }
    }

    // MARK: - Prompt 邮票本

    enum Stamps {
        /// Sidebar widget header
        static func sectionTitle(_ lang: Language) -> String {
            lang == .zh ? "邮票本" : "Stamps"
        }
        /// 空状态文案
        static func emptyTitle(_ lang: Language) -> String {
            lang == .zh ? "还没有邮票" : "No stamps yet"
        }
        static func emptyHint(_ lang: Language) -> String {
            lang == .zh ? "盖第一张 prompt 邮票" : "Make your first stamp"
        }
        /// "…还有 N 张" overflow row
        static func overflowMore(count: Int, _ lang: Language) -> String {
            lang == .zh ? "…还有 \(count) 张" : "…and \(count) more"
        }
        /// Tooltip on stamp hover
        static func hoverHint(_ lang: Language) -> String {
            lang == .zh ? "点击复制到剪贴板" : "Click to copy"
        }

        /// Editor sheet title
        static func editorNewTitle(_ lang: Language) -> String {
            lang == .zh ? "新邮票" : "New stamp"
        }
        static func editorEditTitle(_ lang: Language) -> String {
            lang == .zh ? "编辑邮票" : "Edit stamp"
        }
        static func fieldTitle(_ lang: Language) -> String {
            lang == .zh ? "标签" : "Title"
        }
        static func fieldTitlePlaceholder(_ lang: Language) -> String {
            lang == .zh ? "例如：重构这段" : "e.g. Refactor this"
        }
        static func fieldEmojiColor(_ lang: Language) -> String {
            lang == .zh ? "Emoji + 颜色" : "Emoji + color"
        }
        static func fieldBody(_ lang: Language) -> String {
            lang == .zh ? "Prompt 内容" : "Prompt body"
        }
        static func fieldBodyPlaceholder(_ lang: Language) -> String {
            lang == .zh ? "贴你的 prompt …" : "Paste your prompt…"
        }
        static func fieldPin(_ lang: Language) -> String {
            lang == .zh ? "钉在邮票本（最多 5 张）" : "Pin to sidebar (max 5)"
        }
        static func saveAction(_ lang: Language) -> String {
            lang == .zh ? "盖章保存" : "Save"
        }
        static func cancelAction(_ lang: Language) -> String {
            lang == .zh ? "取消" : "Cancel"
        }

        /// 右键菜单
        static func menuEdit(_ lang: Language) -> String { lang == .zh ? "编辑" : "Edit" }
        static func menuPin(_ lang: Language) -> String { lang == .zh ? "钉住" : "Pin" }
        static func menuUnpin(_ lang: Language) -> String { lang == .zh ? "取消钉住" : "Unpin" }
        static func menuDelete(_ lang: Language) -> String { lang == .zh ? "删除" : "Delete" }
        static func menuCopy(_ lang: Language) -> String { lang == .zh ? "复制" : "Copy" }

        /// Toast 文案：「✓ 「重构这段」已盖章到剪贴板」
        static func toastCopied(_ title: String, _ lang: Language) -> String {
            if title.isEmpty {
                return lang == .zh ? "✓ 邮票已盖章" : "✓ Stamp copied"
            }
            return lang == .zh ? "✓ 「\(title)」已盖章" : "✓ \"\(title)\" copied"
        }

        /// Archive sheet 标题
        static func archiveTitle(_ lang: Language) -> String {
            lang == .zh ? "我的邮票本" : "My stamp book"
        }
        static func archiveSubtitle(_ lang: Language) -> String {
            lang == .zh ? "全部 prompt 邮票" : "All prompt stamps"
        }
        static func sortByUseCount(_ lang: Language) -> String { lang == .zh ? "按用度" : "Most used" }
        static func sortByRecent(_ lang: Language) -> String { lang == .zh ? "按时间" : "Recent" }
        static func sortByName(_ lang: Language) -> String { lang == .zh ? "按字母" : "Alphabetical" }
        static func useCountLabel(_ count: Int, _ lang: Language) -> String {
            lang == .zh ? "用过 \(count) 次" : "\(count) uses"
        }
        static func pinnedBadge(_ lang: Language) -> String {
            lang == .zh ? "钉" : "Pinned"
        }
        /// Add new stamp button hint
        static func addNewHint(_ lang: Language) -> String {
            lang == .zh ? "新建邮票" : "New stamp"
        }
        /// "All stamps" 入口 hint
        static func allHint(_ lang: Language) -> String {
            lang == .zh ? "看全部" : "See all"
        }
    }

    // MARK: - 邮局音效（opt-in）

    enum SoundEffects {
        static func sectionHeader(_ lang: Language) -> String {
            lang == .zh ? "音效 / Sounds" : "Sounds / 音效"
        }
        static func toggleTitle(_ lang: Language) -> String {
            lang == .zh ? "邮局音效" : "Postal sound effects"
        }
        static func toggleHint(_ lang: Language) -> String {
            lang == .zh
                ? "推送 / 信件到达 / 蜡封信开启时的轻量提示音（默认关；尊重系统音量）"
                : "Soft cues on push / letter arrival / wax seal open (off by default; respects system volume)"
        }
        static func scenesFooter(_ lang: Language) -> String {
            lang == .zh
                ? "仅 4 个高价值时刻：推送成功 · 每日信件投递 · 新版推送 · 蜡封信开启"
                : "Only 4 high-value moments: push success · daily letter delivery · update push · seal break"
        }
    }

    // MARK: - AI 工具配置（per-repo detection badge）

    /// 仓库里检测到 AI 工具配置时显示。**诚实边界**：
    /// 永远说"Configured for / 在这仓库里看到了"，永不说"由 X 维护"
    /// —— 配置文件存在不代表当前活跃使用
    // MARK: - Sidebar 扫描状态指示

    enum Scanning {
        /// PanelSidebar 底部 PostalScanIndicator 的文案（仓库扫盘进行中）
        static func sidebarHint(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "巡视小邮局…"
            case (.friendly, .en): return "Making rounds…"
            case (.minimal, .zh):  return "扫描中"
            case (.minimal, .en):  return "Scanning"
            }
        }
    }

    enum AIRepo {
        /// Detail view 里 chip 行的引导文案
        static func configuredFor(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "在这仓库里看到了："
            case (.friendly, .en): return "Configured for:"
            case (.minimal, .zh):  return "配置："
            case (.minimal, .en):  return "Setup:"
            }
        }
        /// hover 单个 stamp 时的 tooltip
        static func stampTooltip(tool: AITool, _ lang: Language) -> String {
            lang == .zh
                ? "在此仓库找到 \(tool.displayName) 的配置文件"
                : "Found \(tool.displayName) configuration in this repo"
        }
    }

    // MARK: - Commit 通知（opt-in 本地新邮件提醒）

    enum Notification {
        /// Settings section 标题
        static func sectionHeader(_ lang: Language) -> String {
            lang == .zh ? "通知 / Notifications" : "Notifications / 通知"
        }
        /// Toggle 主标题
        static func toggleTitle(_ lang: Language) -> String {
            lang == .zh ? "新邮件提醒" : "New mail alerts"
        }
        /// Toggle hint —— 解释做什么 + 隐私不打扰
        static func toggleHint(_ lang: Language) -> String {
            lang == .zh
                ? "扫到新 commit 时给你一封系统通知（默认关，需 macOS 通知权限）"
                : "Banner when a new commit is detected (off by default; needs macOS permission)"
        }
        /// 解释 throttle 行为
        static func coalesceFooter(_ lang: Language) -> String {
            lang == .zh
                ? "Pilo 会等你停下手 60 秒后再投递 —— 不会一直叮叮咚咚"
                : "Pilo waits 60s of quiet before delivery — no constant pings"
        }
    }

    // MARK: - S1 AI Push Guard

    enum AIAudit {
        static func likelyAITooltip(_ lang: Language) -> String {
            lang == .zh ? "看起来像 AI 写的 commit" : "Looks like an AI-written commit"
        }
        static func maybeAITooltip(_ lang: Language) -> String {
            lang == .zh ? "可能是 AI 写的" : "Possibly AI-written"
        }
    }

    // MARK: - S2 跨 Repo 工作日报

    enum DailyDigest {
        static func cardTitle(_ lang: Language, dateString: String) -> String {
            lang == .zh ? "今日邮局 · \(dateString)" : "Today's Post · \(dateString)"
        }
        static func sectionPushed(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "— 今日寄出 · \(count) 封 —" }
            return count == 1 ? "— Sent today · 1 letter —" : "— Sent today · \(count) letters —"
        }
        static func sectionDrafting(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "— 还在写 · \(count) 个 —" }
            return count == 1 ? "— Drafting · 1 —" : "— Drafting · \(count) —"
        }
        static func sectionVisited(count: Int, _ lang: Language) -> String {
            if lang == .zh { return "— 今天看过 · \(count) 个 —" }
            return count == 1 ? "— Visited · 1 —" : "— Visited · \(count) —"
        }
        static func emptyState(_ tone: Tone, _ lang: Language) -> String {
            switch (tone, lang) {
            case (.friendly, .zh): return "今天还没寄出过信"
            case (.friendly, .en): return "Nothing posted today yet"
            case (.minimal, .zh):  return "今日无活动"
            case (.minimal, .en):  return "No activity today"
            }
        }
        static func commitCountSuffix(_ count: Int, _ lang: Language) -> String {
            if lang == .zh { return "\(count) 个 commit" }
            return count == 1 ? "1 commit" : "\(count) commits"
        }
        static func collapseLabel(_ lang: Language) -> String {
            lang == .zh ? "收起" : "Collapse"
        }
        static func expandLabel(_ lang: Language) -> String {
            lang == .zh ? "展开" : "Expand"
        }
    }

    // MARK: - S3 Identity Sentinel

    enum Identity {
        // Settings 配置区
        static func sectionHeader(_ lang: Language) -> String {
            lang == .zh ? "身份分拣" : "Identity Pool"
        }
        static func sectionHint(_ lang: Language) -> String {
            lang == .zh
                ? "为每类仓库绑定一个 git 邮箱，push 前 Pilo 会自动核对"
                : "Bind a git email per category — Pilo will cross-check on push"
        }
        static func emailFieldLabel(_ cat: RepoCategory, _ lang: Language) -> String {
            switch (cat, lang) {
            case (.work, .zh):       return "工作邮箱"
            case (.work, .en):       return "Work email"
            case (.personal, .zh):   return "个人邮箱"
            case (.personal, .en):   return "Personal email"
            case (.experiment, .zh): return "实验邮箱（留空跟个人）"
            case (.experiment, .en): return "Experiment (defaults to Personal)"
            default:                 return ""
            }
        }
        static func emailFieldPlaceholder(_ cat: RepoCategory, _ lang: Language) -> String {
            switch (cat, lang) {
            case (.work, .zh):       return "例如 you@company.com"
            case (.work, .en):       return "e.g. you@company.com"
            case (.personal, .zh):   return "例如 12345+username@users.noreply.github.com"
            case (.personal, .en):   return "e.g. 12345+username@users.noreply.github.com"
            case (.experiment, .zh): return ""
            case (.experiment, .en): return ""
            default:                 return ""
            }
        }

        // Push preflight warning banner
        static func mismatchTitle(_ lang: Language) -> String {
            lang == .zh ? "身份对不上号" : "Identity mismatch"
        }
        static func mismatchBody(category: RepoCategory, expected: String, actual: String,
                                 count: Int, _ lang: Language) -> String {
            let catName = Copy.Inventory.categoryLabel(category, lang)
            if lang == .zh {
                let s = count == 1 ? "" : "（共 \(count) 个）"
                return "这是 \(catName) 仓库，但 commit author 是 \(actual)\(s)，期望的是 \(expected)。"
            } else {
                return "This is a \(catName) repo, but commit author is \(actual) (\(count) commits) — expected \(expected)."
            }
        }
        static func fixAuthorButton(_ lang: Language) -> String {
            lang == .zh ? "一键修正 author" : "Fix author config"
        }
        static func ignoreOnceButton(_ lang: Language) -> String {
            lang == .zh ? "仅本次忽略" : "Ignore this time"
        }
        static func fixedHint(_ lang: Language) -> String {
            lang == .zh
                ? "已把 git config user.email 改成期望值（仅影响未来 commit，历史不动）"
                : "Updated git config user.email (affects future commits only, history untouched)"
        }
    }

    // MARK: - AI 工具 menu

    enum AILauncher {
        static func openInButton(_ lang: Language) -> String {
            lang == .zh ? "在 AI 中打开" : "Open in AI"
        }
        // "请位 AI 助手" / "Send for an editor" —— 邮局派遣的叙事
        // ("send for the postman" 在英文里是邮政传统用法)
        static func popoverTitle(_ lang: Language) -> String {
            lang == .zh ? "请位 AI 助手" : "Send for an editor"
        }
        static func noToolsDetected(_ lang: Language) -> String {
            lang == .zh
                ? "没检测到 Cursor / Claude Code / Codex / Windsurf / VS Code"
                : "No Cursor / Claude Code / Codex / Windsurf / VS Code detected"
        }
    }

    // MARK: - 关于页面

    enum About {
        static func reopenOnboarding(_ lang: Language) -> String {
            lang == .zh ? "再看一次新手引导" : "Replay onboarding"
        }
        static func reopenOnboardingHint(_ lang: Language) -> String {
            lang == .zh ? "重置引导状态并打开 4 屏" : "Reset onboarding state and reopen the 4-screen flow"
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
