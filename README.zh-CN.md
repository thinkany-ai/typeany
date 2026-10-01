<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="TypeAny">
</p>

<h1 align="center">TypeAny</h1>

<p align="center">
  <strong>会听、会写、还会翻译的 macOS 中文输入法。</strong>
</p>

<p align="center">
  <a href="https://github.com/thinkany-ai/typeany/releases"><img src="https://img.shields.io/github/v/release/thinkany-ai/typeany?include_prereleases&label=release" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <a href="https://github.com/thinkany-ai/typeany/actions/workflows/ci.yml"><img src="https://github.com/thinkany-ai/typeany/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License: AGPL-3.0"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · 简体中文
</p>

---

TypeAny 是用 Swift 写的原生 macOS 输入法（InputMethodKit）：用调校好的 [Rime](https://rime.im)
引擎打拼音，按住一个键就能把话说进输入框，还能用中文写回复、发出去是英文。

## 功能

- **拼音** —— 完整的雾凇拼音词库：整句输入、简拼（`wsm` → 为什么）、候选里混英文单词和 emoji、
  以词定字、日期（`rq`）、计算器。
- **记住你的选择** —— 同一个输入，上次选了哪个候选，下次就排第一；单个字母（`m` → 吗）和完整拼音
  一视同仁，词频也会持续学习。
- **联想** —— 上屏后出现接下来可能要打的词，按 1–5 选择，按其他键继续输入。
- **语音输入** —— 按住快捷键说话，文字边说边出现在输入框里（Apple 语音识别、本地 Whisper 或
  Whisper API），可选大模型润色。
- **中文写，英文发** —— <kbd>⌃⇧T</kbd> 打开翻译模式：用拼音或语音写中文，看着英文预览，按
  <kbd>↩</kbd> 发出英文。使用你配置的 OpenAI 兼容模型，或 Apple 本地翻译。
- **打字细节** —— <kbd>⇧</kbd> 全局切换中/英；`baidu.com` 不会变成「百度。」；中英文之间自动加空格
  （我用 GitHub 写代码）。
- **原生体验** —— 候选窗跟随光标，浅色/深色模式，首次使用有引导。

## 安装

从 [Releases](https://github.com/thinkany-ai/typeany/releases) 下载最新的 `TypeAny-x.y.z.dmg`，打开后
双击 **TypeAny**。它会把自己安装到 `~/Library/Input Methods`、加入输入法菜单，并打开引导完成授权和
第一次体验。安装包使用 Developer ID 签名并经过 Apple 公证。

需要 **macOS 14 Sonoma** 及以上、Apple 芯片。Apple 本地翻译需要 macOS 26。

TypeAny 需要 **麦克风**、**语音识别**（语音输入）和 **辅助功能**（全局语音快捷键）权限，只在按住
语音键时录音。

## 使用

| 按键 | 作用 |
|---|---|
| <kbd>⌃Space</kbd> / <kbd>🌐</kbd> | 切换到 / 切出 TypeAny（系统快捷键） |
| <kbd>Space</kbd> · <kbd>1</kbd>–<kbd>5</kbd> | 选择候选 |
| <kbd>-</kbd> <kbd>=</kbd> | 上一页 / 下一页 |
| <kbd>↩</kbd> | 把打的字母作为英文上屏 |
| <kbd>⇧</kbd>（单击） | 切换中 / 英 |
| <kbd>[</kbd> <kbd>]</kbd> | 以词定字：取词的第一个 / 最后一个字 |
| 按住 <kbd>Fn</kbd> | 语音输入（可修改；右 <kbd>⌥</kbd> 不容易和其他应用冲突） |
| <kbd>⌃⇧T</kbd> | 翻译模式：<kbd>↩</kbd> 发英文，<kbd>⌥↩</kbd> / <kbd>Esc</kbd> 保留中文 |

设置在菜单栏图标和输入法菜单（*TypeAny 设置…*）里。模型 API Key 只保存在本机，只会发送给你配置的服务商。

## 从源码构建

需要 macOS 14+、Xcode（SwiftUI 宏需要完整 Xcode，只装 Command Line Tools 不够；Apple 本地翻译需要
macOS 26 SDK）和以下 Homebrew 依赖：

```bash
brew install librime opencc librsvg
git clone https://github.com/thinkany-ai/typeany.git
cd typeany
make run          # 构建 → 安装 TypeAny Dev 到 ~/Library/Input Methods → 启动
```

| 命令 | 作用 |
|---|---|
| `make build` / `make install` / `make run` | 构建 / 安装 / 安装并启动 **TypeAny Dev** |
| `make install VARIANT=release` | 从源码安装正式版 **TypeAny** |
| `make test` | 拼音候选排序测试 + 中英文自动空格单元测试 |
| `make release` | 打包 librime、签名、公证，生成 DMG + ZIP 到 `dist/`（维护者使用） |
| `make icons` | 从 `assets/logo/*.svg` 重新生成图标 |
| `make rime-data` | 重新生成 Rime 数据（雾凇拼音 + `Rime/`） |

本地构建的是 **TypeAny Dev**：独立的 Bundle ID（`com.typeany.inputmethod.TypeAnyDev`）、输入源、
数据目录（`~/Library/Application Support/TypeAny Dev`）、偏好设置和系统权限，菜单栏带 *Dev* 标记，
开发时不会影响已安装的正式版，两者可以同时启用。传入 `SIGN_IDENTITY="Apple Development: …"`
可以让重新编译后权限不失效。

首次构建会下载固定版本的雾凇拼音并预编译词库（`scripts/build-rime-data.sh`），并用 librime-predict
的语料生成联想表（`scripts/build-predict-data.sh`）。

## 目录结构

```
Sources/TypeAny/
├── App/            入口、AppDelegate（语音流程）、自动安装、自检
├── InputMethod/    IMK 控制器、Rime 封装、候选窗、联想、选择记忆
├── Onboarding/     首次使用引导（独立进程运行）
├── Speech/ Audio/  语音识别引擎与录音
├── LLM/            OpenAI 兼容的润色与翻译
├── HotKey/ MenuBar/ UI/ Preferences/ Utilities/
Sources/CRime/      librime C 接口封装
Rime/               TypeAny 拼音方案（基于雾凇）与高频简拼表
Tests/              拼音候选测试（C）与自动空格测试（Swift）
scripts/            Rime 数据、联想数据、图标、依赖打包、发布
assets/logo/        logo 源文件
```

## 发布

```bash
./scripts/new-version.sh 0.3.0        # 预发布用 0.3.0-beta.1
```

脚本会修改 `Sources/TypeAny/Resources/Info.plist` 的版本号、提交、打标签并推送。随后
[`release.yml`](.github/workflows/release.yml) 把 librime 打包进 App，用 Developer ID 证书签名
（hardened runtime），公证并 staple App 和 DMG，发布 GitHub Release。本地用 `make release` 执行
同样的步骤，读取 `APPLE_SIGNING_IDENTITY`、`APPLE_ID`、`APPLE_PASSWORD`、`APPLE_TEAM_ID` 环境变量；
CI 所需的 Secrets 用 [`scripts/setup-release-secrets.sh`](scripts/setup-release-secrets.sh) 一次性设置。

## 参与贡献

欢迎提 Issue 和 Pull Request，详见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按
[SECURITY.md](SECURITY.md) 私下报告。

## 许可证

TypeAny 采用 [AGPL-3.0](LICENSE) 许可证 © 2026 ThinkAny, LLC。TypeAny 自身代码可另行获得不含 AGPL
传染性义务的商业授权，请联系 support@thinkany.ai。

正式安装包内附带的第三方组件遵循各自的许可证，主要包括 [雾凇拼音](https://github.com/iDvel/rime-ice)
词库（GPL-3.0）和 [librime](https://github.com/rime/librime)（BSD-3-Clause），详见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
