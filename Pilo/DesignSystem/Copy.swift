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
