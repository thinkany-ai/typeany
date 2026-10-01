import SwiftUI
import Cocoa

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var onTriggerKeyChanged: (() -> Void)?
    /// Called whenever a setting that the status menu mirrors changes.
    var onPreferencesChanged: (() -> Void)?

    func show(tab: SettingsTab = .general) {
        // Show a Dock icon + app menu while the window is open, like a regular app
        NSApp.setActivationPolicy(.regular)

        if let window = window {
            NotificationCenter.default.post(name: .typeanySelectSettingsTab, object: tab)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            initialTab: tab,
            onTriggerKeyChanged: { [weak self] in self?.onTriggerKeyChanged?() },
            onPreferencesChanged: { [weak self] in self?.onPreferencesChanged?() }
        )

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "TypeAny"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 880, height: 620))
        window.minSize = NSSize(width: 760, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let typeanySelectSettingsTab = Notification.Name("typeanySelectSettingsTab")
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, speech, ai, hotWords, history, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "设置"
        case .speech: return "语音识别"
        case .ai: return "AI 润色"
        case .hotWords: return "热词"
        case .history: return "历史记录"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .speech: return "waveform"
        case .ai: return "sparkles"
        case .hotWords: return "character.book.closed"
        case .history: return "clock.arrow.circlepath"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @State private var tab: SettingsTab
    let onTriggerKeyChanged: () -> Void
    let onPreferencesChanged: () -> Void

    init(initialTab: SettingsTab, onTriggerKeyChanged: @escaping () -> Void, onPreferencesChanged: @escaping () -> Void) {
        _tab = State(initialValue: initialTab)
        self.onTriggerKeyChanged = onTriggerKeyChanged
        self.onPreferencesChanged = onPreferencesChanged
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .frame(maxHeight: .infinity)
                .background(Color.primary.opacity(0.035))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tab.title)
                        .font(.system(size: 26, weight: .bold))
                        .padding(.bottom, 24)
                    content
                }
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(tab)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea()
        .frame(minWidth: 760, minHeight: 520)
        .tint(Brand.color)
        .onReceive(NotificationCenter.default.publisher(for: .typeanySelectSettingsTab)) { note in
            if let t = note.object as? SettingsTab { tab = t }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 26, height: 26)
                Text("TypeAny")
                    .font(.system(size: 17, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.top, 48)
            .padding(.bottom, 20)

            ForEach(SettingsTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(item.title)
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tab == item ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general:
            GeneralSettingsPane(onTriggerKeyChanged: onTriggerKeyChanged, onPreferencesChanged: onPreferencesChanged)
        case .speech:
            SpeechSettingsPane()
        case .ai:
            AISettingsPane(onPreferencesChanged: onPreferencesChanged)
        case .hotWords:
            HotWordsPane()
        case .history:
            HistoryPane(onPreferencesChanged: onPreferencesChanged)
        case .about:
            AboutPane()
        }
    }
}

// MARK: - Building blocks

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            Divider()
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.top, 18)
        }
        .padding(.bottom, 36)
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let control: Control

    init(_ title: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
                .frame(minWidth: 220, alignment: .trailing)
        }
    }
}

private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
    }
}

private struct HintText: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    let onTriggerKeyChanged: () -> Void
    let onPreferencesChanged: () -> Void

    @State private var triggerKey = PreferencesManager.shared.triggerKey
    @State private var customCombo = PreferencesManager.shared.customKeyCombo
    @State private var isRecordingKey = false
    @State private var keyRecorder: KeyRecorder?
    @State private var language = PreferencesManager.shared.selectedLanguage
    @State private var liveTyping = PreferencesManager.shared.liveTypingEnabled
    @State private var vad = PreferencesManager.shared.vadEnabled

    var body: some View {
        SettingsSection(title: "快捷键", icon: "keyboard") {
            SettingsRow("语音输入", subtitle: "按住开始说话，松开结束并输入文字。") {
                VStack(alignment: .trailing, spacing: 8) {
                    Picker("", selection: $triggerKey) {
                        ForEach(TriggerKey.allCases.filter { $0 != .custom }, id: \.self) { key in
                            Text(key.displayName).tag(key)
                        }
                        if let combo = customCombo {
                            Text("自定义：\(combo.displayString)").tag(TriggerKey.custom)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    HStack(spacing: 8) {
                        if isRecordingKey {
                            Text("请按下按键…（Esc 取消）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let combo = customCombo {
                            KeyCap(text: combo.displayString)
                        }
                        Button(isRecordingKey ? "取消" : "录制自定义按键") {
                            isRecordingKey ? cancelKeyRecording() : startKeyRecording()
                        }
                    }
                }
            }
            if let hint = triggerKey.hint {
                HintText(text: hint)
            }
        }
        .onChange(of: triggerKey) {
            PreferencesManager.shared.triggerKey = triggerKey
            onTriggerKeyChanged()
        }

        SettingsSection(title: "语言", icon: "globe") {
            SettingsRow("识别语言", subtitle: "语音输入时使用的语言。") {
                Picker("", selection: $language) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        .onChange(of: language) {
            AppState.shared.updateLanguage(language)
            onPreferencesChanged()
        }

        SettingsSection(title: "输入行为", icon: "text.cursor") {
            SettingsRow("实时上屏", subtitle: "说话时文字实时出现在输入框中（仅 Apple ASR）。") {
                Toggle("", isOn: $liveTyping).toggleStyle(.switch).labelsHidden()
            }
            SettingsRow("静音自动停止", subtitle: "检测到 1.5 秒静音后自动结束录音。") {
                Toggle("", isOn: $vad).toggleStyle(.switch).labelsHidden()
            }
        }
        .onChange(of: liveTyping) {
            PreferencesManager.shared.liveTypingEnabled = liveTyping
            onPreferencesChanged()
        }
        .onChange(of: vad) {
            PreferencesManager.shared.vadEnabled = vad
            onPreferencesChanged()
        }
        .onDisappear { cancelKeyRecording() }
    }

    private func startKeyRecording() {
        isRecordingKey = true
        let recorder = KeyRecorder()
        recorder.onRecorded = { combo in
            PreferencesManager.shared.customKeyCombo = combo
            customCombo = combo
            isRecordingKey = false
            keyRecorder = nil
            if triggerKey == .custom {
                // Same selection, so onChange won't fire; reload the hotkey ourselves
                onTriggerKeyChanged()
            } else {
                triggerKey = .custom
            }
        }
        recorder.onCancelled = {
            isRecordingKey = false
            keyRecorder = nil
        }
        keyRecorder = recorder
        recorder.startRecording()
    }

    private func cancelKeyRecording() {
        keyRecorder?.stopRecording()
        keyRecorder = nil
        isRecordingKey = false
    }
}

// MARK: - Speech

private struct SpeechSettingsPane: View {
    @State private var engine = PreferencesManager.shared.asrEngine
    @State private var modelPath = PreferencesManager.shared.whisperModelPath
    @State private var apiBaseURL = PreferencesManager.shared.whisperAPIBaseURL
    @State private var apiKey = PreferencesManager.shared.whisperAPIKey
    @State private var apiModel = PreferencesManager.shared.whisperAPIModel
    @State private var whisperInstalled = WhisperLocalEngine.isInstalled()
    @State private var modelExists = WhisperLocalEngine.modelExists(at: PreferencesManager.shared.whisperModelPath)

    var body: some View {
        SettingsSection(title: "识别引擎", icon: "waveform") {
            VStack(spacing: 10) {
                engineCard(.apple, title: "Apple ASR", subtitle: "免费 · 实时 · 系统自带")
                engineCard(.localWhisper, title: "本地 Whisper", subtitle: "免费 · 离线 · 需安装 whisper-cpp")
                engineCard(.whisperAPI, title: "Whisper API", subtitle: "按量付费 · 准确率最高")
            }
        }
        .onChange(of: engine) { PreferencesManager.shared.asrEngine = engine }

        if engine == .localWhisper {
            SettingsSection(title: "本地 Whisper", icon: "internaldrive") {
                if !whisperInstalled {
                    HintText(text: "未检测到 whisper-cpp，请先运行：brew install whisper-cpp")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("模型文件").font(.system(size: 13, weight: .medium))
                    HStack {
                        TextField("~/.typeany/models/ggml-base.bin", text: $modelPath)
                            .textFieldStyle(.roundedBorder)
                        Button("选择…") { browseModel() }
                    }
                }
                if !modelExists {
                    HintText(text: "模型文件未找到。下载地址：huggingface.co/ggerganov/whisper.cpp")
                }
            }
            .onChange(of: modelPath) {
                PreferencesManager.shared.whisperModelPath = modelPath
                modelExists = WhisperLocalEngine.modelExists(at: modelPath)
            }
        }

        if engine == .whisperAPI {
            SettingsSection(title: "Whisper API", icon: "cloud") {
                LabeledField(label: "Base URL", placeholder: "留空复用 AI 润色的设置", text: $apiBaseURL)
                LabeledField(label: "API Key", placeholder: "留空复用 AI 润色的 API Key", text: $apiKey, secure: true)
                LabeledField(label: "模型", placeholder: "whisper-1", text: $apiModel)
            }
            .onChange(of: apiBaseURL) { PreferencesManager.shared.whisperAPIBaseURL = apiBaseURL }
            .onChange(of: apiKey) { PreferencesManager.shared.whisperAPIKey = apiKey }
            .onChange(of: apiModel) { PreferencesManager.shared.whisperAPIModel = apiModel }
        }
    }

    private func engineCard(_ type: ASREngineType, title: String, subtitle: String) -> some View {
        let selected = engine == type
        return Button {
            engine = type
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Brand.color : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Brand.color.opacity(0.08) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Brand.color : Color.primary.opacity(0.12)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func browseModel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.typeany/models")
        if panel.runModal() == .OK, let url = panel.url {
            modelPath = url.path
        }
    }
}

// MARK: - AI

private struct AISettingsPane: View {
    let onPreferencesChanged: () -> Void

    @State private var enabled = PreferencesManager.shared.llmEnabled
    @State private var baseURL = PreferencesManager.shared.llmAPIBaseURL
    @State private var apiKey = PreferencesManager.shared.llmAPIKey
    @State private var model = PreferencesManager.shared.llmModel
    @State private var testResult = ""
    @State private var testSucceeded = false
    @State private var isTesting = false

    var body: some View {
        SettingsSection(title: "润色", icon: "sparkles") {
            SettingsRow("启用 AI 润色", subtitle: "识别完成后用大模型修正错别字、去掉口头语并整理标点。") {
                Toggle("", isOn: $enabled).toggleStyle(.switch).labelsHidden()
            }
        }
        .onChange(of: enabled) {
            PreferencesManager.shared.llmEnabled = enabled
            onPreferencesChanged()
        }

        SettingsSection(title: "模型服务", icon: "server.rack") {
            Text("兼容 OpenAI Chat Completions 接口的任意服务。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            LabeledField(label: "API Base URL", placeholder: "https://api.openai.com/v1", text: $baseURL)
            LabeledField(label: "API Key", placeholder: "sk-…", text: $apiKey, secure: true)
            LabeledField(label: "模型", placeholder: "gpt-4o-mini", text: $model)
            HStack(spacing: 12) {
                Button(isTesting ? "测试中…" : "测试连接") { testConnection() }
                    .disabled(isTesting || baseURL.isEmpty || apiKey.isEmpty || model.isEmpty)
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testSucceeded ? .green : .red)
                }
            }
        }
        .onChange(of: baseURL) { PreferencesManager.shared.llmAPIBaseURL = baseURL }
        .onChange(of: apiKey) { PreferencesManager.shared.llmAPIKey = apiKey }
        .onChange(of: model) { PreferencesManager.shared.llmModel = model }
    }

    private func testConnection() {
        isTesting = true
        testResult = ""
        Task {
            let (ok, message): (Bool, String)
            do {
                ok = try await LLMRefiner().testConnection()
                message = ok ? "连接成功" : "失败：服务端返回错误"
            } catch {
                ok = false
                message = "失败：\(error.localizedDescription)"
            }
            await MainActor.run {
                testSucceeded = ok
                testResult = message
                isTesting = false
            }
        }
    }
}

// MARK: - Hot Words

private struct HotWordsPane: View {
    @State private var words: [(from: String, to: String)] = HotWordsManager.shared.hotWords
    @State private var newFrom = ""
    @State private var newTo = ""

    var body: some View {
        SettingsSection(title: "纠错词表", icon: "character.book.closed") {
            Text("把经常识别错的词替换成正确写法。不开启 AI 润色也生效。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("识别结果（如 配森）", text: $newFrom)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField("正确写法（如 Python）", text: $newTo)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addWord)
                Button("添加", action: addWord)
                    .disabled(newFrom.trimmingCharacters(in: .whitespaces).isEmpty
                              || newTo.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if words.isEmpty {
                Text("还没有热词")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, pair in
                        if index > 0 { Divider() }
                        HStack {
                            Text(pair.from).foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(pair.to).fontWeight(.medium)
                            Spacer()
                            Button {
                                HotWordsManager.shared.removeHotWord(at: index)
                                words = HotWordsManager.shared.hotWords
                            } label: {
                                Image(systemName: "xmark").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
            }
        }
    }

    private func addWord() {
        let from = newFrom.trimmingCharacters(in: .whitespaces)
        let to = newTo.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        HotWordsManager.shared.addHotWord(from: from, to: to)
        newFrom = ""
        newTo = ""
        words = HotWordsManager.shared.hotWords
    }
}

// MARK: - History

private struct HistoryPane: View {
    let onPreferencesChanged: () -> Void
    @State private var history = PreferencesManager.shared.injectionHistory
    @State private var copiedIndex: Int?

    var body: some View {
        SettingsSection(title: "最近输入", icon: "clock.arrow.circlepath") {
            if history.isEmpty {
                Text("还没有语音输入记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.offset) { index, text in
                        if index > 0 { Divider() }
                        HStack(alignment: .top) {
                            Text(text)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                                copiedIndex = index
                            } label: {
                                Image(systemName: copiedIndex == index ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("复制")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))

                Button("清空历史记录", role: .destructive) {
                    PreferencesManager.shared.clearHistory()
                    history = []
                    onPreferencesChanged()
                }
            }
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TypeAny").font(.system(size: 22, weight: .bold))
                    Text("版本 \(version)").foregroundStyle(.secondary)
                    Text("说话即输入，拼音与语音一体的输入法。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)

            SettingsSection(title: "帮助", icon: "questionmark.circle") {
                SettingsRow("使用引导", subtitle: "重新查看权限设置与使用说明。") {
                    Button("打开") { OnboardingLauncher.launch() }
                }
                SettingsRow("GitHub", subtitle: "反馈问题、查看源码。") {
                    Button("访问") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/thinkany-ai/typeany")!)
                    }
                }
            }
        }
    }
}
