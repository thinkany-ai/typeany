# TypeAny - macOS Voice Input

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

A lightweight macOS menu-bar app for voice input. Hold a trigger key to record, release to transcribe and inject text into any focused input field.

## ⚡ Install

### Homebrew (recommended)

```bash
brew tap thinkany-ai/tap
brew install typeany
```

Then launch:
```bash
open $(brew --prefix)/opt/typeany/TypeAny.app
# or symlink to Applications:
ln -sf $(brew --prefix)/opt/typeany/TypeAny.app /Applications/TypeAny.app
```

### One-line script

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/thinkany-ai/typeany/main/install.sh)"
```

> Both methods require macOS 14+ and Xcode Command Line Tools (`xcode-select --install`)

## ✨ Features

- **Customizable trigger key** — Right Option ⌥ (recommended), Fn, Right ⌘/⌃, Caps Lock, F5/F6, or any custom combo
- **Streaming ASR** — real-time transcription via Apple Speech (default: zh-CN)
- **Multi-engine ASR** — choose from 3 engines in Settings:
  - 🍎 Apple ASR (free, real-time, online)
  - 🖥️ Local Whisper (free, offline, `brew install whisper-cpp`)
  - ☁️ Whisper API (OpenAI-compatible, best accuracy)
- **Elegant capsule HUD** — floating waveform panel driven by real-time audio RMS
- **VAD auto-stop** — silence detection stops recording after 1.5s pause
- **Hot words** — custom correction pairs (e.g. 配森 → Python)
- **LLM refinement** — conservative error correction via OpenAI-compatible API
- **History** — last 10 injections, re-inject with one click
- **CJK-aware injection** — auto-switches to ABC keyboard before paste, restores after
- **LSUIElement** — menu bar only, no Dock icon

## 🚀 Manual Build

```bash
git clone https://github.com/thinkany-ai/typeany.git
cd typeany
make build    # compile and create .app bundle
make run      # build and launch
make install  # install to /Applications
make clean    # clean build artifacts
```

## ⚙️ Configuration

Click the menu bar icon to access:

| Setting | Description |
|---------|-------------|
| **Trigger Key** | Choose or record a custom hotkey (Right ⌥ recommended if Fn is taken by WeChat) |
| **Language** | English / 简体中文 / 繁體中文 / 日本語 / 한국어 |
| **ASR Engine** | Apple ASR / Local Whisper / Whisper API |
| **Auto Stop (VAD)** | Toggle silence-based auto-stop |
| **Hot Words** | Custom corrections dictionary |
| **LLM Refinement** | Configure API for smarter corrections |
| **Recent History** | Re-inject previous transcriptions |

### First Launch Permissions

1. **Microphone** — for recording
2. **Speech Recognition** — for transcription  
3. **Accessibility** — for hotkey monitoring and text injection

## 🏗️ Architecture

```
Sources/TypeAny/
├── App/            # Entry point, AppDelegate, AppState
├── Audio/          # AVAudioEngine recording + RMS levels
├── HotKey/         # HotkeyMonitor (customizable trigger keys)
├── LLM/            # OpenAI-compatible refinement client
├── MenuBar/        # Status bar controller
├── Preferences/    # UserDefaults, language, hot words
├── Speech/         # ASR engines (Apple / Whisper Local / Whisper API)
├── TextInjection/  # Clipboard + Cmd+V injection
├── UI/             # Floating panel, waveform, settings windows
└── Utilities/      # Constants, permissions
```

## 📝 License

MIT
