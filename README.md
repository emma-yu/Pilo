# Pilo 🕊️

> 一只帮你安全推送代码的小信鸽
>
> macOS 菜单栏小工具 · 自动发现 Git 仓库 · push 前扫敏感信息

完整产品文档：`/Users/yuqianyu/Documents/Pilo-PRD-v1.1.md`

---

## 当前状态

**v0.1.0-dev** — Phase 0~3 已落地（脚手架、仓库发现、菜单栏、首次启动 Onboarding）。

可用：
- ✅ 菜单栏小图标 + popover
- ✅ 自动发现指定目录下的 Git 仓库
- ✅ 显示分支 / ahead / behind / 未提交计数
- ✅ 首次启动 4 屏 Onboarding 引导
- ✅ Tone 设置（friendly / minimal）
- ✅ 仓库列表持久化到 `~/Library/Application Support/Pilo/state.json`

尚未实现（后续 Phase）：
- ⏳ git push（Phase 5）
- ⏳ SecretScanner 敏感信息扫描（Phase 6）
- ⏳ 误提交防护、kill switch（Phase 6/7）
- ⏳ 自动 git fetch（Phase 4）
- ⏳ Pilo mascot 真实视觉资产（用 SF Symbol 占位）
- ⏳ 离线队列（v0.2）、Stash Inbox（v0.3）

---

## 构建运行

```bash
# 一次性：安装 xcodegen（如未安装）
brew install xcodegen

# 生成 Xcode 工程
cd ~/Code/Pilo
xcodegen generate

# 打开
open Pilo.xcodeproj
```

在 Xcode 中：
1. 顶部 scheme 选 **Pilo**，Destination 选 **My Mac**
2. cmd+R 运行
3. 看菜单栏右上角应出现一个鸟形小图标 🐦
4. 首次启动会自动弹出 Onboarding window

环境要求：
- macOS 14.0+
- Xcode 16.0+
- Swift 6.0+
- 系统 `git` 命令（macOS 自带 / Xcode Command Line Tools / Homebrew git 均可）

---

## 架构

```
Pilo/
  PiloApp.swift              — @main，4 个 Scene
  DesignSystem/              — Colors / Typography / Animations / Copy / Tone
  Models/                    — Repository / AppState / AppSettings / AppPaths
  Core/                      — GitClient (actor) / RepoScanner (actor) / FSEventMonitor
  Views/
    MenuBarView              — popover 内容
    MainWindow/              — 两栏主窗口
    Onboarding/              — 4 屏首启引导
    Settings/                — 设置面板
    Components/              — PiloMascot / StatusBadge / RepoCard 等
```

**关键设计决策**：
- `@MainActor @Observable final class AppState` — 跨 Scene 状态用 macOS 14 Observation 框架（不是 ObservableObject）
- `actor GitClient` — git 子进程封装；强制 `LANG=C.UTF-8` + `GIT_TERMINAL_PROMPT=0` + `GIT_OPTIONAL_LOCKS=0`；所有 Process 显式 Pipe 三路 stream（Phase 5 push 凭证交互的伏笔）
- **App Sandbox 关闭，Hardened Runtime 开启** — git 子进程要跑用户任意路径；走 Developer ID 直接分发；如未来上 Mac App Store 需要走 security-scoped bookmarks
- 持久化：JSON 文件 `~/Library/Application Support/Pilo/state.json`，顶层带 `version` 字段方便未来迁移
- 文案：String Catalog（`.xcstrings`），Xcode 16 原生支持；friendly + minimal 双 tone

---

## 本会话偏离 PRD 处

| 偏离 | 原文 | 调整 | 理由 |
|---|---|---|---|
| 文案存储 | PRD §3.3 `Localizable.strings` | `.xcstrings` String Catalog | Xcode 16 原生，diff 友好 |
| 持久化 | PRD §3.1 Core Data + JSON | 只用 JSON | Phase 0-3 不需要时间序列 |
| Mascot | PRD 附录 A 要求 7 SVG | SF Symbol `bird.fill` + 不同 tint 占位 | PRD §9 第 3 条允许 |
| AppIcon | PRD 附录 A 要求 1024×1024 | 仅 `Contents.json` 骨架 | 等视觉资产 |
| 英文文案 | PRD §3.3 双语 | 本会话只填中文，xcstrings 留 en 列待填 |

---

## License

MIT
