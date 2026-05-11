# Pilo 🕊️

> 一只帮你安全推送代码的小信鸽
>
> macOS 菜单栏小工具 · 自动发现 Git 仓库 · push 前扫敏感信息 · 双语 zh/en

---

## 📚 文档

- **[IMPLEMENTATION.md](./IMPLEMENTATION.md)** — **完整实现记录**（架构 / 所有功能 / 数据模型 / 设计系统 / 测试 / commit 旅程 / 扩展指南）
- `~/Documents/Pilo-PRD-v1.1.md` — 原始 PRD（产品哲学和 Phase 列表仍是权威源；UI 细节已偏离）

新人入坑请先读 IMPLEMENTATION.md §1（架构）和 §3（功能清单）。

---

## 当前状态

**v3.8** — Phase 0~7 全部落地，UI 完成 Pilo 邮局风重设计，加上 i18n / 真实 GitHub visibility。

可用：
- ✅ 菜单栏 popover + 主窗口（衬线 Songti SC + 金线邮局风）
- ✅ 自动发现 Git 仓库（递归 + FSEvents 增量）
- ✅ 真实 GitHub 公开/私有检测（无 token）
- ✅ 4 屏 Onboarding（Welcome / Directories / Privacy / Complete）
- ✅ Push 流程（preflight / running / completed 全 UI + 7 种错误分类）
- ✅ 敏感信息扫描（25 条规则 + Shannon 熵 + 误报记忆）
- ✅ 误提交防护（.env / 私钥 / 大文件 / 构建产物）
- ✅ Kill switch 24h 临停 + .gitignore 幂等编辑
- ✅ 双语切换 zh ↔ en × Tone friendly/minimal 4 变体
- ✅ 88 个测试全绿
- ✅ 仓库列表持久化（`~/Library/Application Support/Pilo/state.json`，PAT 强制脱敏）

未做（v0.2+）：
- ⏳ Stash Inbox（Phase 8）
- ⏳ 离线推送队列 / 自动 fetch / launch-at-login
- ⏳ Pilo SVG 真实多 mood 资产
- ⏳ Mac App Store 沙盒模式

详见 [IMPLEMENTATION.md §13 已知限制](./IMPLEMENTATION.md#13-已知限制--未做项)。

---

## 构建运行

```bash
# 一次性：安装 xcodegen
brew install xcodegen

# 生成 Xcode 工程
cd ~/Code/Pilo
xcodegen generate

# 打开
open Pilo.xcodeproj
```

在 Xcode 中：
1. Scheme = **Pilo**，Destination = **My Mac**
2. cmd+R 运行
3. 菜单栏右上会出现星星图标 ✨
4. 首次启动自动弹 Onboarding window

跑测试：
```bash
xcodebuild test -project Pilo.xcodeproj -scheme Pilo -destination 'platform=macOS'
```

环境要求：
- macOS 14.0+
- Xcode 16.0+
- Swift 6.0+
- 系统 `git`（自带 / CLT / Homebrew 均可）

---

## License

MIT
