<div align="center">

# Pilo · Post Office

*A serif menu bar pigeon for your Git repos.*

**Beautiful by design. Local by principle.**

<br>

![Pilo screenshot placeholder — main panel](./docs/screenshots/main-panel.png)

<br>

[简体中文](./README_zh.md) · [Architecture notes](./IMPLEMENTATION.md) · [License](./LICENSE)

</div>

---

## What it is

Pilo is a macOS menu bar app that watches every Git repo on your Mac.

It quietly remembers which ones haven't been pushed yet, which have uncommitted drafts,
which are off in their own corner. When you do push, it takes a careful look first —
a small heads-up if something looks like a leaked API key, a `.env` file, or a 50 MB
binary that probably shouldn't be in Git.

No accounts. No telemetry. No cloud. Just a pigeon.

## Why it looks like this

Most developer tools are built like spreadsheets — dense, square, neutral.
Pilo is built like a letter — Songti SC serif headings, gold ornament lines,
cream paper cards, a breathing mascot. Inspired by the small ceremony of
posting a letter at a Chinese-style post office.

It is opinionated about feel because feel is what makes a tool you actually
keep around.

## What's inside

- **Multi-repo dashboard** — see ahead / behind / uncommitted across every repo at a glance
- **Push-time scanning** — 25 secret-detection rules + 6 commit-guard categories (.env, private keys, oversized blobs)
- **Real GitHub visibility** — public / private pill via the unauthenticated GitHub API, cached 24h
- **4-screen onboarding** — Songti SC serif + breathing mascot + 4-segment progress
- **Bilingual** — Chinese ↔ English × friendly ↔ minimal tone (Tone × Language matrix)
- **Custom postal-style settings** — paper card pickers instead of system controls
- **Two ways to add scan folders** — file picker or paste a path (`~/Code`, `/Users/you/projects`, quoted, with tilde)
- **All local** — repository metadata in `~/Library/Application Support/Pilo/state.json`; the only network call is GitHub visibility detection

## How it looks

| | |
|---|---|
| ![menu bar popover](./docs/screenshots/menubar.png) | ![main panel](./docs/screenshots/panel.png) |
| ![onboarding](./docs/screenshots/onboarding.png) | ![settings](./docs/screenshots/settings.png) |

*(Screenshots coming. Build from source today.)*

## Install

**From source** (the only option right now):

```bash
brew install xcodegen
git clone https://github.com/emma-yu/Pilo.git
cd Pilo
xcodegen generate
open Pilo.xcodeproj
```

Requirements: macOS 14.0+, Xcode 16+, Swift 6.0+.

A signed `.dmg` is on the wishlist. ⌘ a star if you want it sooner.

## Design system

Twenty-one named color tokens, twelve font sizes split across SF Pro Rounded
and Songti SC, three elevation tiers using PiloBlue-tinted shadows (no flat
black), four animation presets including a 2.5s mascot breathing loop.

The system is documented in [IMPLEMENTATION.md §7](./IMPLEMENTATION.md#7--设计系统).

## Tech

- Swift 6.0 strict concurrency
- SwiftUI `MenuBarExtra` + `Window` + `Settings` scenes
- `@MainActor @Observable` AppState with eight `actor`-backed services
- `FSEventStream` with `kFSEventStreamCreateFlagUseCFTypes` for incremental repo discovery
- App Sandbox off, Hardened Runtime on (git subprocess needs arbitrary path access)
- ~9 000 lines of Swift, 88 tests across 9 suites

See [IMPLEMENTATION.md](./IMPLEMENTATION.md) for the full architecture record —
data models, every actor's API, persistence schema, copy-string matrix,
commit-by-commit evolution.

## Status

v3.8 — Phases 0 through 7 of the original PRD shipped. Multi-repo discovery,
menu bar overview, onboarding, push flow, secret scanner, commit guard, kill
switch, i18n, real GitHub visibility detection. Stash Inbox (Phase 8) and
offline push queue are next.

## Contributing

Issues and PRs welcome. If you want to add a secret-detection rule, the format
is in `Pilo/Resources/secret-rules.json` — one entry plus a test case in
`PiloTests/SecretScannerTests.swift`.

For larger contributions, please open an issue first so we can talk shape.

## License

MIT — see [LICENSE](./LICENSE).

---

<div align="center">

*Made with serif typography and patience by <a href="https://github.com/emma-yu">@emma-yu</a>.*

</div>
