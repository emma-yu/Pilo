<div align="center">

# Pilo · 邮局

*衬线菜单栏小信鸽，看护你的 Git 仓库。*

**纯本地。AI 友好。像写信，不是仪表盘。**

<br>

![Pilo 主界面](./docs/screenshots/main-panel.png)

<br>

[English](./README.md) · [License](./LICENSE)

</div>

---

## 这是啥

一只常驻 macOS 菜单栏的小信鸽，自动发现你电脑上所有 Git 仓库。

它记得哪些还没 push、哪些有未提交的草稿、哪些自己窝在角落里。push 之前先仔细看一遍——把疑似泄露的 API key、`.env` 文件、50MB 大块头标出来。每天傍晚 6 点写一封关于今天 commit 的信，扔进信箱让你像翻真信一样翻看。

无账号、无埋点、无云端。唯一两个外发网络调用：一天一次的版本检查、看仓库 public/private 时的 GitHub 公共 API。

## 为啥长这样

主流开发者工具都长得像表格——密、方、中性。Pilo 长得像信——**衬线 Songti SC** 标题、**金色装饰线**、**奶油色卡纸**、会呼吸的鸽子吉祥物。灵感来自中式邮局寄一封信的小仪式感。

对"手感"有执念。因为只有手感会让一个工具被你留下来。

## 里面有啥

### 🛡️ 安全
- **Push 前扫描** —— 25 条敏感信息规则 + 6 类误提交（.env / 私钥 / 大文件）
- **身份哨兵** —— 工作 / 个人 / 实验类仓库分别贴邮戳，commit 时 user.email 不匹配会被标出来
- **真实公开/私有检测** —— 无 token GitHub 公共 API，24h 缓存

### 📬 陪伴
- **每日邮局信件** —— 18:00 自动写一封今日 commit + 草稿总结，归档在可翻的信箱
- **版本通告信** —— 每次新版本随 app bundled，新功能 / 改动以信件形式送达
- **Commit 通知** —— opt-in macOS 推送（60s 防扰窗口，默认关——你的注意力不是用来卖的）

### ✉️ Prompt 邮票本
- **邮票本** —— 把常用 AI prompt 存成插画邮票，一键复制到任何 AI 工具
- **桌面浮动 dock** *(v0.5)* —— 屏幕边缘一枚小邮票，拖到任意位置记住；点击展开扇形菜单
- **钉到首位 ✦** *(v0.5)* —— 二级 pin，让最常用 prompt 永远排在最前面
- **邮局风右键菜单** —— 奶油卡纸 + 金线，告别系统蓝色 NSMenu

### 🤖 AI 友好
- **AI 工具邮戳** —— 仓库里有 `CLAUDE.md` / `.cursorrules` / `GEMINI.md` / `AGENTS.md` / `CONVENTIONS.md` 自动盖对应邮戳
- **AI commit 探测** —— 启发式标记"这条 commit 可能是 AI 协作写的"（**仅你自己看，不外发不报告**）
- **项目文档面板** —— 每个仓库的 README / AI 指南 / 架构文档分类展示，自带 Markdown 预览 + ⌘F 全文搜

### 🌐 打磨
- **双语切换** —— 中 ↔ 英 × 温和 ↔ 简洁 4 变体 Copy 矩阵
- **减弱动态效果支持** —— fan-out / stagger 动画尊重 macOS 辅助功能偏好
- **邮局风自定义控件** —— 卡片 picker 代替系统 form chrome

## 视觉

| | |
|---|---|
| ![菜单栏弹窗](./docs/screenshots/menubar.png) | ![主面板](./docs/screenshots/panel.png) |
| ![每日信件](./docs/screenshots/letter.png) | ![邮票本](./docs/screenshots/stamps.png) |

*(截图随每个版本更新。)*

## 安装

### 预编译版本（推荐）

从 [Releases](https://github.com/emma-yu/Pilo/releases/latest) 下载最新 `.zip`：

1. 下载 `Pilo-v*.zip` 并解压
2. 把 `Pilo.app` 拖到 `/应用程序`
3. **首次启动**：Pilo 目前还没公证，Gatekeeper 会拦截。**右键 `Pilo.app` → 打开 → 确认**（一次性）。后续启动正常。
4. 点菜单栏小鸽子。

系统要求：**macOS 14.0+**（Sonoma）。

### 从源码构建

```bash
brew install xcodegen
git clone https://github.com/emma-yu/Pilo.git
cd Pilo
xcodegen generate
open Pilo.xcodeproj
```

环境：macOS 14.0+ · Xcode 16+ · Swift 6.0+。

## 隐私

Pilo 把你的代码和工作模式默认当成私有的。

### 留在本机的
- **仓库元数据** —— `~/Library/Application Support/Pilo/state.json`
- **每日信件归档** —— 同一目录的 `letters.json`
- **版本通告归档** —— `release-letters.json`
- **Prompt 邮票** —— `prompt-stamps.json`
- **所有扫描结果** —— 永不持久化，每次启动重算

### 离开本机的
只有两个 HTTP GET 请求，都是公共端点，无认证、无 body、无埋点：

| 时机 | URL | 用途 |
|---|---|---|
| 约每 24h | `https://raw.githubusercontent.com/emma-yu/Pilo/main/updates.json` | 检查 Pilo 新版本 |
| 首次看到一个仓库时（24h 缓存）| `https://api.github.com/repos/{owner}/{name}` | 公开/私有标记 |

无统计、无崩溃报告、无用户账号。下面的源码就是最权威的答案。

## 设计系统

21 个色彩 token、12 个字号（SF Pro Rounded + Songti SC）、3 档 piloBlue 暖蓝阴影、12 张插画邮票资产 + 鸽子吉祥物。

## 技术栈

- Swift 6.0 严格并发
- SwiftUI `MenuBarExtra` + `Window` + `Settings`
- `@MainActor @Observable` `AppState` + 10+ `actor` 服务
- `FSEventStream` 增量发现仓库
- AppKit `NSEvent.mouseLocation` 驱动浮动 dock 拖动（跳出 SwiftUI window-coord 的局限）
- App Sandbox **关**（git 子进程要任意路径访问），Hardened Runtime **开**
- ~14 kLoC Swift，263 测试分布在 23 套件

## 发布机制

Pilo 用两套机制分发，**都是纯本地**，不依赖 Sparkle，不依赖自动安装：

1. **App bundle 内的 release notes**（`Pilo/Resources/release-notes.json`）—— 已升级用户首次启动新版本时收到一封 "v0.X 邮局通告" 信，跟每日信件同一个信箱
2. **远端更新清单**（`updates.json` 在仓库根，由 GitHub raw 提供）—— 还在旧版本的用户后台 `UpdateChecker` 每 24h 轮询，发现新版本就送一封 "v0.X · 新版已发车" 信

新装用户首启信箱是空的——历史版本通告不会回放。

## 当前状态

**v0.5** —— Phase 0–7 + Phase B + Sprint S1–S4 已发：

- 多仓库发现、push 流、敏感信息扫描、误提交防护
- 4 屏 Onboarding、Kill Switch、国际化
- 每日信件、Companion 簇、身份哨兵（S3）
- AI commit 探测、AI 工具邮戳、commit 通知
- 项目文档面板、Markdown 预览
- Prompt 邮票本、浮动 dock 自适应 fan-out、钉到首位 ✦

后续候选：离线 push 队列、开机自启、签名 .dmg、多显示器浮动 dock。

## 贡献

Issue / PR 都欢迎。

- **加一条敏感信息规则**：`Pilo/Resources/secret-rules.json` 加一条 + `PiloTests/SecretScannerTests.swift` 加一个测试。格式在源文件里有
- **大改**：先开 issue 聊聊，Pilo 对 UX 和品牌一致性有强约束，**聊比 PR review 快**
- **不调用 LLM** 是硬产品 invariant，再诱人都不能加

## License

MIT —— 见 [LICENSE](./LICENSE)。

---

<div align="center">

*衬线体 + 耐心打磨 · <a href="https://github.com/emma-yu">@emma-yu</a>*

</div>
