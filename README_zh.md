<div align="center">

# Pilo · 邮局

*一只常驻菜单栏的小信鸽*

**纯本地 · 不调 LLM · 代码不离开 Mac**

<br>

![Pilo 主界面](./docs/screenshots/main-panel.png)

<br>

[English](./README.md) · [官网](https://xinxinmingde.com/pilo.html) · [License](./LICENSE)

</div>

---

## 一句话

AI 让一个人同时写 10 个项目 —— Pilo 替你看着全部：哪个还在 draft、哪个 30 天没动、常用 prompt 一键召唤，傍晚 18:00 一封信回顾今天。顺便，push 之前替你过一眼。

## GitHub 的小绿格回答不了这些

- *我昨天到底动了哪些项目？*
- *那个 30 天没碰的 fork 还在不在？*
- *这个仓库我用的是 work 邮箱还是 personal？*
- *我那条「解释这段代码」的 prompt 又找不到了？*

脑子里那张地图，越用 AI 越糊。Pilo 替你拿着，用 GitHub 从没想过的方式。

## 四张邮票

### 01 · 仓库陪伴

自动发现你电脑上每一个 Git 仓库，分成**活跃 / 静默 / 沉寂**三段，让你一眼看到哪个角落需要关注。每个仓库都贴一枚小邮戳，告诉你它跟哪个 AI 工具在协作（`CLAUDE.md` → Claude Code 邮戳，`.cursorrules` → Cursor 邮戳，以此类推）。

### 02 · 每日邮局信件

每天 18:00，Pilo 给你写一封关于今天 commit 和草稿的信，宋体衬线中文或英文。过往信件像真信一样可翻可读，存在信箱里。版本通告也以「邮局通告」的形式送到同一个信箱 —— release notes 像信，不像弹窗。

### 03 · 邮票本浮动 Dock

二级邮票本浮在屏幕边——拖到你的手最自然落下的地方。点一下，常用 prompt 围成一圈展开。给最常用的盖一枚 ✦，永远排第一。一键复制到任何 AI：Cursor、Claude Code、Aider、浏览器 ChatGPT。

### 04 · Push 前安全检查

每次 `git push` 之前，Pilo 用 25 条敏感信息规则 + 6 类误提交守护扫一遍 diff。`.env` 文件、私钥、大块头 blob、AWS / OpenAI / Anthropic / GitHub token —— 都是**确定性规则**（正则 + 熵阈值）抓住的，不是 AI 猜的。「身份哨兵」还会标记 user.email 跟仓库 work/personal/experiment 邮戳不匹配的 commit。

## 为什么长这样

主流开发者工具长得像表格——密、方、中性。Pilo 长得像信。**宋体衬线 · 暖纸色 · 金色装饰线 · 暖白信纸卡 · 旋转邮戳 · 会呼吸的真鸽子吉祥物。** 灵感来自中式邮局寄一封信的小仪式感。

**慢一拍的设计，反而能让人留下来。**

## 安装

从 [Releases](https://github.com/emma-yu/Pilo/releases/latest) 下载最新 `.zip`：

1. 下载 `Pilo-v*.zip` 并解压
2. 把 `Pilo.app` 拖到 `/应用程序`
3. **首次启动**：Pilo 目前还没经过 Apple 公证，macOS Gatekeeper 会拦截。**右键 `Pilo.app` → 打开 → 确认**（一次性）。之后正常启动即可。
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

品牌承诺：**代码不离开你的 Mac。没有 telemetry，没有 analytics，没有崩溃上报，没有账号。**

### 留在本机的
- `state.json` — 仓库元数据
- `letters.json` — 每日信件归档
- `release-letters.json` — 版本通告
- `prompt-stamps.json` — 你的邮票本

都在 `~/Library/Application Support/Pilo/`。所有扫描结果（敏感信息 / .env hits 等）**永不持久化**——每次启动重算，只在内存里。

### 离开本机的
只有两个无认证的公共 HTTP GET 请求。无 body、无认证、无指纹：

| 时机 | URL | 用途 |
|---|---|---|
| 约每 24h | `https://raw.githubusercontent.com/emma-yu/Pilo/main/updates.json` | 检查 Pilo 新版本 |
| 首次见到一个仓库时（24h 缓存）| `https://api.github.com/repos/{owner}/{name}` | 公开 / 私有标记 |

就这两个。下面的源码就是最权威的答案。

## 技术栈

- Swift 6.0 严格并发 · SwiftUI `MenuBarExtra` / `Window` / `Settings`
- `@MainActor @Observable` `AppState` + 10+ `actor` 服务
- `FSEventStream` 增量发现仓库
- AppKit `NSEvent.mouseLocation` 驱动浮动 dock（跳出 SwiftUI window-coord 的局限）
- App Sandbox **关**（git 子进程要任意路径访问），Hardened Runtime **开**
- ~14 kLoC Swift，263 测试分布在 23 套件

## 发布机制

Pilo 用两套机制分发，**都是纯本地**，不依赖 Sparkle，不依赖自动安装：

1. **App bundle 内的 release notes**（`Pilo/Resources/release-notes.json`）—— 已升级用户首次启动新版本时收到一封 「v0.X 邮局通告」信，跟每日信件同一个信箱
2. **远端更新清单**（`updates.json` 在仓库根，由 GitHub raw 提供）—— 还在旧版本的用户后台 `UpdateChecker` 每 24h 轮询，发现新版本就送一封 「v0.X · 新版已发车」信

新装用户首启信箱是空的——历史版本通告不会回放。

## 当前状态

**v0.5** —— 第一次正式公开。Phase 0–7 + Phase B + Sprint S1–S4 已发：

- 多仓库发现、push 流、敏感信息扫描、误提交防护
- 4 屏 Onboarding、Kill Switch、双语国际化
- 每日信件、身份哨兵（S3）、Companion 簇
- AI commit 探测、AI 工具邮戳、commit 通知
- 项目档案、文档面板、Markdown 预览
- Prompt 邮票本、浮动 dock 自适应 fan-out、钉到首位 ✦

后续候选：离线 push 队列 · 开机自启 · 签名 .dmg · 多显示器浮动 dock。

## Links

- 📮 **[Pilo 官网](https://xinxinmingde.com/pilo.html)** —— 故事、截图、设计灵感
- 🐦 **[GitHub Releases](https://github.com/emma-yu/Pilo/releases)** —— 下载最新 `.zip`
- 📜 **[LICENSE](./LICENSE)** —— MIT

## 贡献

Issue / PR 都欢迎。

- **加一条敏感信息规则**：`Pilo/Resources/secret-rules.json` 加一条 + `PiloTests/SecretScannerTests.swift` 加一个测试。格式在源文件里有
- **大改**：先开 issue 聊聊。Pilo 对 UX 和品牌一致性有强约束，**聊比 PR review 快**
- **app 内不调用 LLM** 是硬产品 invariant，再诱人都不能加

## License

MIT —— 见 [LICENSE](./LICENSE)。

---

<div align="center">

*衬线体 + 耐心打磨 · <a href="https://github.com/emma-yu">@emma-yu</a>*

</div>
