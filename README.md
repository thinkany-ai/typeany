<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="TypeAny">
</p>

<h1 align="center">TypeAny</h1>

<p align="center">
  <strong>A Chinese input method for macOS that listens, types and translates.</strong>
</p>

<p align="center">
  <a href="https://github.com/thinkany-ai/typeany/releases"><img src="https://img.shields.io/github/v/release/thinkany-ai/typeany?include_prereleases&label=release" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <a href="https://github.com/thinkany-ai/typeany/actions/workflows/ci.yml"><img src="https://github.com/thinkany-ai/typeany/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License: AGPL-3.0"></a>
</p>

<p align="center">
  English · <a href="README.zh-CN.md">简体中文</a>
</p>

---

TypeAny is a native macOS input method (InputMethodKit) written in Swift. Type pinyin with a
well-tuned [Rime](https://rime.im) engine, hold a key to dictate straight into the text field, or
write a reply in Chinese and send it in English.

## Features

- **Pinyin** — full rime-ice (雾凇拼音) dictionaries: whole-sentence input, abbreviations
  (`wsm` → 为什么), English words and emoji among candidates, 以词定字, dates (`rq`), a calculator.
- **Remembers your choices** — the candidate you picked last for an input comes first next time,
  for single letters (`m` → 吗) as much as full pinyin; word frequencies are learned too.
- **Next-word suggestions (联想)** — after committing, likely next words appear; press 1–5 to pick,
  any other key to keep typing.
- **Voice input** — hold the trigger key and speak; text streams into the field as you talk
  (Apple Speech, local Whisper or a Whisper API), with optional LLM clean-up.
- **Write Chinese, send English** — <kbd>⌃⇧T</kbd> turns on translate mode: compose in Chinese (typed
  or spoken), see the English preview, press <kbd>↩</kbd> to send it. Uses your OpenAI-compatible
  model, or Apple's on-device translation.
- **Typing details** — <kbd>⇧</kbd> toggles 中/英 globally, `baidu.com` stays a domain instead of
  becoming 百度。, and a space is added automatically between Chinese and English (我用 GitHub 写代码).
- **Native** — candidate window under the caret, light/dark mode, guided onboarding.

## Install

Download the latest `TypeAny-x.y.z.dmg` from [Releases](https://github.com/thinkany-ai/typeany/releases),
open it and double-click **TypeAny**. It installs itself into `~/Library/Input Methods`, adds
itself to the input menu and opens the onboarding, which walks through permissions and a first try.
Builds are signed with a Developer ID and notarized by Apple.

Requires **macOS 14 Sonoma** or later on Apple silicon. On-device translation needs macOS 26.

TypeAny asks for **Microphone** and **Speech Recognition** (voice input) and **Accessibility**
(the global voice key). It only records while the voice key is held.

## Usage

| Key | Action |
|---|---|
| <kbd>⌃Space</kbd> / <kbd>🌐</kbd> | Switch to / from TypeAny (system shortcut) |
| <kbd>Space</kbd> · <kbd>1</kbd>–<kbd>5</kbd> | Pick a candidate |
| <kbd>-</kbd> <kbd>=</kbd> | Previous / next page |
| <kbd>↩</kbd> | Commit the typed letters as English |
| <kbd>⇧</kbd> (tap) | Toggle 中 / 英 |
| <kbd>[</kbd> <kbd>]</kbd> | Take the first / last character of a word (以词定字) |
| Hold <kbd>Fn</kbd> | Voice input (configurable; right <kbd>⌥</kbd> avoids conflicts with other apps) |
| <kbd>⌃⇧T</kbd> | Translate mode: <kbd>↩</kbd> sends English, <kbd>⌥↩</kbd> / <kbd>Esc</kbd> keeps Chinese |

Settings live in the menu bar icon and the input menu (*TypeAny Settings…*). Model API keys are
stored locally and only sent to the provider you configure.

## Build from source

Requirements: macOS 14+, Xcode (SwiftUI macros need the full Xcode, not just the Command Line
Tools; macOS 26 SDK for the on-device translation path) and Homebrew packages:

```bash
brew install librime opencc librsvg
git clone https://github.com/thinkany-ai/typeany.git
cd typeany
make run          # build → install TypeAny Dev into ~/Library/Input Methods → launch
```

| Command | What it does |
|---|---|
| `make build` / `make install` / `make run` | Build / install / install and launch **TypeAny Dev** |
| `make install VARIANT=release` | Install the regular **TypeAny** from source |
| `make test` | Pinyin candidate-order tests and auto-spacing unit tests |
| `make release` | Bundle librime, sign, notarize and package DMG + ZIP into `dist/` (maintainers) |
| `make icons` | Regenerate icons from `assets/logo/*.svg` |
| `make rime-data` | Rebuild the Rime data (rime-ice + `Rime/`) |

Local builds are **TypeAny Dev**: a separate bundle ID (`com.typeany.inputmethod.TypeAnyDev`), input
source, data folder (`~/Library/Application Support/TypeAny Dev`), preferences and permissions,
with a *Dev* label in the menu bar — so developing never touches an installed release and both can
be enabled side by side. Pass `SIGN_IDENTITY="Apple Development: …"` to keep permissions across
rebuilds.

The first build downloads rime-ice at a pinned revision and prebuilds its dictionaries
(`scripts/build-rime-data.sh`), and builds the next-word table from librime-predict's corpus
(`scripts/build-predict-data.sh`).

## Project layout

```
Sources/TypeAny/
├── App/            entry point, AppDelegate (voice pipeline), self-installer, self-test
├── InputMethod/    IMK controller, Rime wrapper, candidate window, prediction, selection memory
├── Onboarding/     first-run window (runs as a separate process)
├── Speech/ Audio/  speech engines and recording
├── LLM/            OpenAI-compatible refiner and translator
├── HotKey/ MenuBar/ UI/ Preferences/ Utilities/
Sources/CRime/      C shim over librime's API
Rime/               TypeAny schema (on top of rime-ice) and high-frequency abbreviations
Tests/              pinyin candidate tests (C) and auto-spacing tests (Swift)
scripts/            Rime data, prediction data, icons, library bundling, release
assets/logo/        logo sources
```

## Releasing

```bash
./scripts/new-version.sh 0.3.0        # or 0.3.0-beta.1 for a pre-release
```

It bumps the version in `Sources/TypeAny/Resources/Info.plist`, commits, tags and pushes.
[`release.yml`](.github/workflows/release.yml) then bundles librime into the app, signs it with the
Developer ID certificate (hardened runtime), notarizes and staples the app and DMG, and publishes a
GitHub Release. The same steps run locally with `make release`, using the `APPLE_SIGNING_IDENTITY`,
`APPLE_ID`, `APPLE_PASSWORD` and `APPLE_TEAM_ID` environment variables. CI secrets are set once
with [`scripts/setup-release-secrets.sh`](scripts/setup-release-secrets.sh).

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Please report
security problems privately as described in [SECURITY.md](SECURITY.md).

## License

TypeAny is licensed under [AGPL-3.0](LICENSE) © 2026 ThinkAny, LLC. A commercial license without
the AGPL's copyleft obligations is available for TypeAny's own code — contact support@thinkany.ai.

Release builds bundle third-party components under their own licenses, notably the
[rime-ice](https://github.com/iDvel/rime-ice) dictionaries (GPL-3.0) and
[librime](https://github.com/rime/librime) (BSD-3-Clause); see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
