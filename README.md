# TypeAny - macOS Voice Input

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

A lightweight macOS menu-bar app for voice input. Hold **Fn** to record, release to transcribe and inject text into any focused input field.

## ✨ Features

- **Hold Fn to record** — global CGEvent tap, suppresses emoji picker
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

## 🚀 Quick Start

### Requirements
- macOS 14+
- Xcode command line tools or Swift 5.9+

### Build & Run

```bash
git clone https://github.com/thinkany-ai/typeany.git
cd typeany
make build    # compile and create .app bundle
make run      # build and launch
make install  # install to /Applications
make clean    # clean build artifacts
```

### First Launch

Grant the following permissions when prompted:
1. **Microphone** — for recording
2. **Speech Recognition** — for transcription
3. **Accessibility** — for Fn key monitoring and text injection

## ⚙️ Configuration

Click the menu bar icon to access:

- **Language** — English / 简体中文 / 繁體中文 / 日本語 / 한국어
- **ASR Engine** — Apple ASR / Local Whisper / Whisper API
- **Auto Stop (VAD)** — toggle silence-based auto-stop
- **Hot Words** — custom corrections dictionary
- **LLM Refinement** — enable/configure API for smarter corrections
- **Recent History** — re-inject previous transcriptions

## 🏗️ Architecture

```
Sources/TypeAny/
├── App/            # Entry point, AppDelegate, AppState
├── Audio/          # AVAudioEngine recording + RMS levels
├── HotKey/         # Fn key CGEvent tap monitor
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
