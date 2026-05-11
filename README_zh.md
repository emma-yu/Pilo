<div align="center">

# Pilo · 邮局

*一只住在菜单栏里的小信鸽，守着你 Mac 上所有 Git 仓库。*

**慢工出细活。本地优先。**

<br>

![Pilo 主面板截图（待补）](./docs/screenshots/main-panel.png)

<br>

[English](./README.md) · [实现记录](./IMPLEMENTATION.md) · [License](./LICENSE)

</div>

---

## 这是什么

Pilo 是一个常驻 macOS 菜单栏的小应用。它默默记着你这台机器上每一个 Git 仓库：
哪些还没推送，哪些有未提交的草稿，哪些被遗忘在角落里。

当你真的要推送的时候，它会先帮你看一眼 —— 是不是有看起来像 API key 的字符串，
是不是不小心把 `.env` 加进去了，是不是有个 50 MB 的二进制文件躺在 commit 里。

没账户，没遥测，不上云。就一只信鸽。

## 为什么它长这样

大多数开发者工具看起来像 Excel 表格 —— 密、方、没温度。
Pilo 看起来像一封信 —— 宋体衬线标题、金色装饰线、信纸黄卡片、会呼吸的鸽子。
灵感来自中式邮局里寄一封信那种小小的仪式感。

它在"手感"上有自己的执念，因为**手感是让你愿意每天打开它的原因**。

## 它能做什么

- **多仓库总览** —— 一眼看清每个仓库 ahead / behind / 未提交 状态
- **推送前扫描** —— 25 条敏感信息检测规则 + 6 大类误提交防护（.env / 私钥 / 超大文件）
- **真实公开/私有指示** —— 走 GitHub 公共 API（无 token），24 小时缓存
- **4 屏 Onboarding** —— 宋体 + 呼吸鸽子 + 4 段进度条
- **中英文双语 + Friendly/Minimal 两种 tone** —— 4 个文案变体矩阵
- **邮局风设置面板** —— 信纸卡片 picker，不用系统组件
- **添加扫描目录两种方式** —— 文件选择器，或直接粘贴路径（支持 `~/Code`、引号、空格 trim）
- **完全本地** —— 仓库元数据存 `~/Library/Application Support/Pilo/state.json`；唯一网络请求是查 GitHub 公开/私有

## 截图

| | |
|---|---|
| ![菜单栏弹窗](./docs/screenshots/menubar.png) | ![主面板](./docs/screenshots/panel.png) |
| ![Onboarding](./docs/screenshots/onboarding.png) | ![设置](./docs/screenshots/settings.png) |

*（截图待补。目前可以从源码编译。）*

## 安装

**从源码编译**（现阶段唯一方式）：

```bash
brew install xcodegen
git clone https://github.com/emma-yu/Pilo.git
cd Pilo
xcodegen generate
open Pilo.xcodeproj
```

环境要求：macOS 14.0+、Xcode 16+、Swift 6.0+。

签名 `.dmg` 在 wishlist 上。Star 一下就来得快一点。

## 设计系统

21 个命名色，12 个字号分布在 SF Pro Rounded（圆体）和 Songti SC（衬线）两套字体，
3 档基于 PiloBlue 暖蓝阴影的 elevation（不用纯黑），4 个 animation preset
包括 2.5 秒的 mascot 呼吸循环。

完整 token 在 [IMPLEMENTATION.md §7](./IMPLEMENTATION.md#7--设计系统)。

## 技术

- Swift 6.0 严格并发
- SwiftUI `MenuBarExtra` + `Window` + `Settings` scenes
- `@MainActor @Observable` 全局 AppState + 8 个 actor 后台
- `FSEventStream` 增量监听（用 `kFSEventStreamCreateFlagUseCFTypes` 避免崩溃）
- App Sandbox 关闭，Hardened Runtime 开启（git 子进程需要任意路径访问）
- 约 9 000 行 Swift，88 个测试分布在 9 个测试套件

完整架构记录见 [IMPLEMENTATION.md](./IMPLEMENTATION.md) —— 数据模型、每个
actor 的 API、持久化 schema、文案矩阵、commit 演进树。

## 当前状态

v3.8 —— 原 PRD 的 Phase 0 到 7 全部落地。多仓库发现、菜单栏总览、Onboarding、
推送流程、敏感信息扫描、误提交防护、kill switch、中英文切换、真实
GitHub 公开/私有检测都跑通了。Stash Inbox（Phase 8）和离线推送队列在 wishlist。

## 贡献

欢迎 issue 和 PR。

加一条敏感信息检测规则：在 `Pilo/Resources/secret-rules.json` 里加一条，
配套在 `PiloTests/SecretScannerTests.swift` 加一个测试用例。

大改动请先开 issue 聊一下方向。

## License

MIT —— 见 [LICENSE](./LICENSE)。

---

<div align="center">

*由 <a href="https://github.com/emma-yu">@emma-yu</a> 用宋体和耐心做的。*

</div>
