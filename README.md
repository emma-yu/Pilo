<div align="center">

# Pilo · Post Office

*Menu-bar companion for indie devs in the AI era.*

**Local-only · No LLM · Code never leaves your Mac**

<br>

*Screenshots & full visual story → [xinxinmingde.com/pilo.html](https://xinxinmingde.com/pilo.html)*

<br>

[简体中文](./README_zh.md) · [官网 / Site](https://xinxinmingde.com/pilo.html) · [License](./LICENSE)

</div>

---

## In one sentence

AI lets one person ship ten projects at once — Pilo watches them all for you: which is still a draft, which hasn't moved in 30 days, your most-used prompts one click away, an evening letter at 6pm to recap today. And, before you push, it takes a quiet look.

## GitHub's little green squares can't answer this

- *Which projects did I touch yesterday?*
- *Is that fork I haven't touched in 30 days even there anymore?*
- *Am I using my work email or personal email in this repo?*
- *That "explain this code" prompt I wrote last week — where is it?*

The mental map of your projects gets blurrier the more you use AI. Pilo holds it for you, in a way GitHub never tried to.

## Four stamps

### 01 · Repository Companion

Auto-discovers every Git repo on your Mac. Groups them by life stage — active / idle / dormant — so you see which corner of your work needs attention. Each repo wears a small postal stamp showing what AI tool it's paired with (`CLAUDE.md` → Claude Code stamp, `.cursorrules` → Cursor stamp, and so on).

### 02 · Daily Postal Letter

At 6pm, Pilo writes you a letter about today's commits and drafts, in serif Chinese or English. Past letters are kept in a flippable inbox, like a real one. Version notes arrive in the same inbox as a "邮局通告" — release announcements feel like mail, not popups.

### 03 · Floating Prompt Stamps

A second-level stamp book floats at the edge of your screen — drag it to wherever your hand naturally goes. Click it, and your most-used prompts fan out in a circle. Pin a stamp with ✦ to keep it always first. One click copies the prompt to any AI tool: Cursor, Claude Code, Aider, ChatGPT in the browser.

### 04 · Pre-push Safety Check

Before any `git push`, Pilo scans the diff with 25 secret-detection rules and 6 commit-guard categories. `.env` files, private keys, oversized blobs, AWS / OpenAI / Anthropic / GitHub tokens — all caught deterministically (regex + entropy), not by guessing. An Identity Sentinel also flags commits where your `user.email` doesn't match the work / personal / experiment tag you put on the repo.

## Why it looks like this

Most developer tools are built like spreadsheets — dense, square, neutral. Pilo is built like a letter. **Songti SC serif headings · cream paper · gold ornament lines · cream-white letter cards · rotating postal seals · a real-pigeon mascot that breathes.** Inspired by the small ceremony of posting a letter at a Chinese-style post office.

A design that takes a beat slower is the kind you keep around.

## Install

Grab the latest `.zip` from [Releases](https://github.com/emma-yu/Pilo/releases/latest):

1. Download `Pilo-v*.zip`, unzip
2. Drag `Pilo.app` to `/Applications`
3. **First launch**: Pilo isn't notarized yet, so macOS Gatekeeper will block it. **Right-click `Pilo.app` → Open → confirm** (once). Subsequent launches work normally.
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

The brand promise: **your code never leaves your Mac. No telemetry. No analytics. No crash reports. No accounts.**

### What stays on your Mac
- `state.json` — repository metadata
- `letters.json` — daily letter archive
- `release-letters.json` — version announcements
- `prompt-stamps.json` — your prompt book

All in `~/Library/Application Support/Pilo/`. Scan findings (secrets, .env hits, etc.) are never persisted — they're recomputed each session and live only in memory.

### What leaves your Mac
Two unauthenticated public HTTP GETs. No body, no auth, no fingerprint:

| When | URL | Why |
|---|---|---|
| ~every 24h | `https://raw.githubusercontent.com/emma-yu/Pilo/main/updates.json` | Check for new Pilo versions |
| First time seeing a repo (24h cache) | `https://api.github.com/repos/{owner}/{name}` | Public / private pill |

That's it. The source below is the authoritative answer.

## Tech

- Swift 6.0 strict concurrency · SwiftUI `MenuBarExtra` / `Window` / `Settings`
- `@MainActor @Observable` `AppState` orchestrating 10+ `actor`-backed services
- `FSEventStream` for incremental repo discovery
- AppKit-level `NSEvent.mouseLocation` for the floating dock (escapes SwiftUI's window-coord limitation)
- App Sandbox **off** (git subprocess needs arbitrary path access), Hardened Runtime **on**
- ~14 kLoC Swift, 263 tests across 23 suites

## Releases

Pilo distributes via two complementary mechanisms — both **purely local**, no Sparkle, no auto-installer:

1. **Bundled release notes** (`Pilo/Resources/release-notes.json`) — already-upgraded users see a "v0.X 邮局通告" letter on first launch of the new version, in the same inbox as their daily letters
2. **Remote update manifest** (`updates.json` at repo root, served by GitHub raw) — users still on an old version have a background `UpdateChecker` that polls every 24h and surfaces a "v0.X · 新版已发车" letter

Fresh installs get an empty inbox — historical announcements aren't replayed.

## Status

**v0.5** — first public release. Phases 0–7 + Phase B + Sprints S1–S4 shipped:

- Multi-repo discovery · push flow · secret scanner · commit guard
- Onboarding 4 screens · kill switch · bilingual i18n
- Daily Letter · Identity Sentinel (S3) · Companion cluster
- AI commit detector · AI tool stamps · commit notifications
- Project Inventory · Project Docs panel · Markdown preview
- Prompt Stamp book · floating dock with adaptive fan-out · pin-to-top ✦

Roadmap candidates: offline push queue · launch-at-login · signed `.dmg` · multi-monitor floating dock.

## Links

- 📮 **[Pilo 官网 / Site](https://xinxinmingde.com/pilo.html)** — story, screenshots, design intent
- 🐦 **[GitHub Releases](https://github.com/emma-yu/Pilo/releases)** — download the latest `.zip`
- 📜 **[LICENSE](./LICENSE)** — MIT

## Contributing

Issues and PRs welcome.

- **Add a secret-detection rule**: one entry in `Pilo/Resources/secret-rules.json` + one test in `PiloTests/SecretScannerTests.swift`. Format is documented inline.
- **Larger changes**: please open an issue first so we can talk shape — Pilo cares a lot about UX and brand consistency, and design alignment is faster as a conversation than as a PR review.
- **No LLM calls in the app itself** is a hard product invariant. Even when tempting.

## License

MIT — see [LICENSE](./LICENSE).

---

<div align="center">

*Made with serif typography and patience by <a href="https://github.com/emma-yu">@emma-yu</a>.*

</div>
