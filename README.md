<div align="center">

# Pilo · Post Office

*A serif menu bar pigeon for your Git repos.*

**Local-only. AI-aware. Designed like a letter, not a dashboard.**

<br>

![Pilo screenshot — main panel](./docs/screenshots/main-panel.png)

<br>

[简体中文](./README_zh.md) · [官网 / Site](https://xinxinmingde.com/pilo.html) · [License](./LICENSE)

</div>

---

## What it is

A macOS menu bar app that watches every Git repo on your Mac.

It remembers which ones haven't been pushed, which have uncommitted drafts, which are off in their own corner. Before a push, it takes a careful look — flags leaked API keys, `.env` files, oversized blobs. At 6pm it composes a letter about your day's commits and drops it in an inbox you can flip through like a real one.

No accounts. No telemetry. No cloud. The only outbound network call is a once-a-day check for app updates and an unauthenticated GitHub API hit for repo visibility.

## Why it looks like this

Most developer tools are built like spreadsheets — dense, square, neutral. Pilo is built like a letter — **Songti SC serif** headings, **gold ornament lines**, **cream paper cards**, a breathing pigeon mascot. Inspired by the small ceremony of posting a letter at a Chinese-style post office.

Opinionated about feel, because feel is what makes a tool you keep around.

## What's inside

### 🛡️ Safety
- **Push-time scanning** — 25 secret-detection rules + 6 commit-guard categories (.env, private keys, oversized blobs)
- **Identity Sentinel** — flag commits where your `user.email` doesn't match the category you tagged on the repo (work / personal / experiment)
- **Real GitHub visibility** — unauthenticated public API, 24h cache; you see at a glance which repos are public

### 📬 Companion
- **Daily letter** — 6pm summary of your commits + drafts, written in serif Chinese / English, archived in a flippable inbox
- **Release letters** — bundled with each version: what changed, why, with the same letter aesthetic
- **Commit notifications** — opt-in macOS banners (60s debounce; default off — your attention isn't for sale)

### ✉️ Prompt Stamps
- **Stamp book** — save reusable AI prompts as illustrated postal stamps, one click copies to any AI tool (Cursor, Claude Code, Aider, browser ChatGPT)
- **Floating desktop dock** *(v0.5)* — pin a stamp icon at the screen edge, drag anywhere, click for a radial fan-out of your top stamps
- **Pin-to-top ✦** *(v0.5)* — second-level pin keeps your most-used prompts always first
- **Postal right-click menus** — cream paper + gold lines instead of system blue

### 🤖 AI Awareness
- **AI tool stamps** — repos with `CLAUDE.md` / `.cursorrules` / `GEMINI.md` / `AGENTS.md` / `CONVENTIONS.md` get a small AI-tool badge
- **AI commit detector** — heuristic flagging of "this commit was likely written with AI" (for your own awareness, never enforcement)
- **Project docs panel** — every repo's README / AI instructions / architecture docs surfaced with a Markdown preview + ⌘F search

### 🌐 Polish
- **Bilingual** — Chinese ↔ English × friendly ↔ minimal tone (4-variant Copy matrix)
- **Reduce Motion** — fan-outs and stagger animations respect macOS accessibility preferences
- **Custom postal-style settings** — paper card pickers instead of system controls

## How it looks

| | |
|---|---|
| ![menu bar popover](./docs/screenshots/menubar.png) | ![main panel](./docs/screenshots/panel.png) |
| ![daily letter](./docs/screenshots/letter.png) | ![stamp book](./docs/screenshots/stamps.png) |

*(Screenshots coming with each release. Build from source today.)*

## Install

### Pre-built (recommended)

Grab the latest `.zip` from [Releases](https://github.com/emma-yu/Pilo/releases/latest):

1. Download `Pilo-v*.zip`, unzip
2. Drag `Pilo.app` to `/Applications`
3. **First launch**: Pilo isn't notarized yet, so Gatekeeper will block it. **Right-click `Pilo.app` → Open → confirm** (once). Subsequent launches work normally.
4. Click the pigeon in your menu bar.

Requirements: **macOS 14.0+** (Sonoma).

### From source

```bash
brew install xcodegen
git clone https://github.com/emma-yu/Pilo.git
cd Pilo
xcodegen generate
open Pilo.xcodeproj
```

Requirements: macOS 14.0+, Xcode 16+, Swift 6.0+.

## Privacy

Pilo treats your code and your work patterns as private by default.

### What stays on your Mac
- **Repository metadata** — `~/Library/Application Support/Pilo/state.json`
- **Daily letters archive** — `letters.json` in the same dir
- **Release letters** — `release-letters.json`
- **Prompt stamps** — `prompt-stamps.json`
- **All scan findings** — never persisted, recomputed each session

### What leaves your Mac
Just two HTTP calls. Both are GETs to public endpoints, no auth, no body, no telemetry:

| When | URL | Why |
|---|---|---|
| ~Every 24h | `https://raw.githubusercontent.com/emma-yu/Pilo/main/updates.json` | Check for new Pilo versions |
| When you first see a repo (24h cache) | `https://api.github.com/repos/{owner}/{name}` | Public/private pill |

No analytics. No crash reports. No user accounts. Source code below is the authoritative answer.

## Design system

Twenty-one color tokens, twelve font sizes across SF Pro Rounded and Songti SC, three elevation tiers using piloBlue-tinted shadows, postal asset library (12 illustrated stamps + mascot).

## Tech

- Swift 6.0 strict concurrency
- SwiftUI `MenuBarExtra` + `Window` + `Settings` scenes
- `@MainActor @Observable` `AppState` with 10+ `actor`-backed services
- `FSEventStream` for incremental repo discovery
- AppKit-level `NSEvent.mouseLocation` for floating dock drag (escapes SwiftUI's window-coord limitation)
- App Sandbox **off** (git subprocess needs arbitrary path access), Hardened Runtime **on**
- ~14 kLoC Swift, 263 tests across 23 suites

## Releases

Pilo distributes through two complementary mechanisms — both **purely local**, no Sparkle, no auto-installer:

1. **Bundled release notes** (`Pilo/Resources/release-notes.json`) — already-upgraded users see a "v0.X 邮局通告" letter on first launch of the new version, in the same inbox as their daily letters
2. **Remote update manifest** (`updates.json` at repo root, served by GitHub raw) — still-on-old-version users' background `UpdateChecker` polls this every 24h, surfaces a "v0.X · 新版已发车" letter when newer

Fresh installs get an empty inbox — historical release letters aren't replayed.

## Status

**v0.5** — Phases 0–7 + Phase B + Sprints S1–S4 shipped:

- Multi-repo discovery, push flow, secret scanner, commit guard
- Onboarding 4 screens, kill switch, i18n
- Daily Letter, Companion cluster, Identity Sentinel (S3)
- AI commit detection, AI tool stamps, AI commit notifications
- Project Inventory, Project Docs panel, Markdown preview
- Prompt Stamp book, floating dock with adaptive fan-out, pin-to-top ✦

Roadmap candidates: offline push queue, launch-at-login, signed .dmg, multi-monitor floating dock.

## Links

- 📮 **[Pilo 官网 / Site](https://xinxinmingde.com/pilo.html)** — story, screenshots, design intent
- 🐦 **[GitHub Releases](https://github.com/emma-yu/Pilo/releases)** — download the latest `.zip`
- 📜 **[LICENSE](./LICENSE)** — MIT

## Contributing

Issues and PRs welcome.

- **Add a secret-detection rule**: one entry in `Pilo/Resources/secret-rules.json` + one test in `PiloTests/SecretScannerTests.swift`. Format is documented inline.
- **Larger changes**: please open an issue first so we can talk shape — Pilo cares a lot about UX and brand consistency, and design alignment is faster as a conversation than as a PR review.
- **No LLM calls** is a hard product invariant. Even if tempting.

## License

MIT — see [LICENSE](./LICENSE).

---

<div align="center">

*Made with serif typography and patience by <a href="https://github.com/emma-yu">@emma-yu</a>.*

</div>
