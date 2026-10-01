# Contributing to TypeAny

Thanks for your interest in improving TypeAny! This guide covers local setup and how to get a
change merged.

## Prerequisites

- macOS 14 or later on Apple silicon (developing on macOS 26 is recommended)
- Xcode — the full Xcode, since SwiftUI macros aren't available with only the Command Line Tools.
  If `xcode-select` points at the Command Line Tools, prefix commands with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- `brew install librime opencc librsvg`

## Setup

```bash
git clone git@github.com:thinkany-ai/typeany.git
cd typeany
make run        # builds TypeAny Dev, installs it into ~/Library/Input Methods and launches it
```

Local builds are **TypeAny Dev** (bundle ID `com.typeany.inputmethod.TypeAnyDev`, data in
`~/Library/Application Support/TypeAny Dev`), isolated from an installed release. Switch to
*TypeAny Dev 拼音* from the input menu to try your change. With an ad-hoc signature, macOS forgets
the Accessibility permission on every rebuild; sign with a development certificate to avoid that:

```bash
make install SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

## Tests

```bash
make test       # pinyin candidate order (Rime) + 中英文 auto-spacing (Swift)
```

When you change the schema (`Rime/`), the abbreviation table or candidate behaviour, add a case to
`Tests/rime/candidates.c`. Logic that doesn't need a running input method is best kept in a pure
type with a test, like `AutoSpacing`.

## Code style

- Match the surrounding code: naming, comment density, and idioms. Comments explain *why*, not
  *what*.
- The input method controller runs on every keystroke — no blocking work there; network
  (translation, LLM) and data loading are asynchronous.
- The onboarding window runs in a separate process (`TypeAny --onboarding`) so it can be a real
  client of the input method; don't open text-input windows from the input method process itself.

## Pull requests

1. Fork and create a branch from `main`.
2. Keep the change focused; describe *what* and *why* in the PR, with screenshots or a recording
   for UI and typing changes.
3. Make sure `make test` and `make build VARIANT=release` succeed (CI runs the same).
4. Try the change in real apps — a native text field, a browser and an Electron app (Slack,
   VS Code) — in both light and dark appearance.

By submitting a pull request you agree that your contribution is licensed under the project's
license (AGPL-3.0).

## Reporting bugs

Open an issue with your macOS version, TypeAny version, the app you were typing in, steps to
reproduce, and what you expected. For security issues, see [SECURITY.md](SECURITY.md) instead.
