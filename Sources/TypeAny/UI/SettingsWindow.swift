import SwiftUI
import Cocoa

final class SettingsWindowController {
    private var window: NSWindow?
    var onTriggerKeyChanged: (() -> Void)?

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            onClose: { [weak self] in
                self?.window?.close()
                self?.window = nil
            },
            onTriggerKeyChanged: { [weak self] in
                self?.onTriggerKeyChanged?()
            }
        )

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "TypeAny - Settings"
        window.setContentSize(NSSize(width: 520, height: 640))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}

struct SettingsView: View {
    let onClose: () -> Void
    var onTriggerKeyChanged: (() -> Void)?

    // Trigger Key
    @State private var triggerKey: TriggerKey
    @State private var customCombo: CustomKeyCombo?
    @State private var isRecordingKey = false
    @State private var keyRecorder: KeyRecorder?

    // ASR Engine
    @State private var asrEngine: ASREngineType
    @State private var whisperModelPath: String
    @State private var whisperAPIBaseURL: String
    @State private var whisperAPIKey: String
    @State private var whisperAPIModel: String
    @State private var whisperInstalled: Bool
    @State private var whisperModelExists: Bool

    // LLM
    @State private var apiBaseURL: String
    @State private var apiKey: String
    @State private var model: String
    @State private var testResult: String = ""
    @State private var isTesting = false

    init(onClose: @escaping () -> Void, onTriggerKeyChanged: (() -> Void)? = nil) {
        self.onClose = onClose
        self.onTriggerKeyChanged = onTriggerKeyChanged
        let prefs = PreferencesManager.shared
        _triggerKey = State(initialValue: prefs.triggerKey)
        _customCombo = State(initialValue: prefs.customKeyCombo)
        _asrEngine = State(initialValue: prefs.asrEngine)
        _whisperModelPath = State(initialValue: prefs.whisperModelPath)
        _whisperAPIBaseURL = State(initialValue: prefs.whisperAPIBaseURL)
        _whisperAPIKey = State(initialValue: prefs.whisperAPIKey)
        _whisperAPIModel = State(initialValue: prefs.whisperAPIModel)
        _whisperInstalled = State(initialValue: WhisperLocalEngine.isInstalled())
        _whisperModelExists = State(initialValue: WhisperLocalEngine.modelExists(at: prefs.whisperModelPath))
        _apiBaseURL = State(initialValue: prefs.llmAPIBaseURL)
        _apiKey = State(initialValue: prefs.llmAPIKey)
        _model = State(initialValue: prefs.llmModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                triggerKeySection
                Divider()
                asrEngineSection
                Divider()
                llmSection
                saveSection
            }
            .padding()
        }
        .frame(width: 520, height: 640)
    }

    // MARK: - Trigger Key Section

    private var triggerKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trigger Key")
                .font(.headline)

            // Dropdown picker for preset keys
            HStack {
                Picker("触发键:", selection: $triggerKey) {
                    ForEach(TriggerKey.allCases.filter { $0 != .custom }, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                    if customCombo != nil {
                        Text("Custom: \(customCombo?.displayString ?? "")").tag(TriggerKey.custom)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280)
            }

            // Hint for selected key
            if let hint = triggerKey.hint {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Record Custom Key button
            HStack(spacing: 10) {
                Button(isRecordingKey ? "Press any key..." : "Record Custom Key") {
                    startKeyRecording()
                }
                .disabled(isRecordingKey)

                if isRecordingKey {
                    Button("Cancel") {
                        cancelKeyRecording()
                    }
                }

                if let combo = customCombo {
                    Text(combo.displayString)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
    }

    private func startKeyRecording() {
        isRecordingKey = true
        let recorder = KeyRecorder()
        recorder.onRecorded = { combo in
            self.customCombo = combo
            self.triggerKey = .custom
            self.isRecordingKey = false
            self.keyRecorder = nil
        }
        recorder.onCancelled = {
            self.isRecordingKey = false
            self.keyRecorder = nil
        }
        self.keyRecorder = recorder
        recorder.startRecording()
    }

    private func cancelKeyRecording() {
        keyRecorder?.stopRecording()
        keyRecorder = nil
        isRecordingKey = false
    }

    // MARK: - ASR Engine Section

    private var asrEngineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASR Engine")
                .font(.headline)

            // Apple ASR
            asrRadioRow(engine: .apple, label: "Apple ASR", subtitle: "免费 · 实时")

            // Local Whisper
            VStack(alignment: .leading, spacing: 6) {
                asrRadioRow(engine: .localWhisper, label: "本地 Whisper", subtitle: "免费 · 离线")

                if asrEngine == .localWhisper {
                    VStack(alignment: .leading, spacing: 6) {
                        if !whisperInstalled {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("请先安装: brew install whisper-cpp")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Model Path:")
                                .font(.caption)
                                .frame(width: 72, alignment: .trailing)
                            TextField("~/.typeany/models/ggml-base.bin", text: $whisperModelPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .onChange(of: whisperModelPath) {
                                    whisperModelExists = WhisperLocalEngine.modelExists(at: whisperModelPath)
                                }
                            Button("Browse") {
                                browseModel()
                            }
                            .font(.caption)
                        }

                        if !whisperModelExists {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("模型文件未找到。下载: huggingface.co/ggerganov/whisper.cpp")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 28)
                }
            }

            // Whisper API
            VStack(alignment: .leading, spacing: 6) {
                asrRadioRow(engine: .whisperAPI, label: "Whisper API", subtitle: "按量付费 · 最强")

                if asrEngine == .whisperAPI {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Base URL:")
                                .font(.caption)
                                .frame(width: 72, alignment: .trailing)
                            TextField("https://api.openai.com/v1 (留空复用 LLM 设置)", text: $whisperAPIBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                        HStack {
                            Text("API Key:")
                                .font(.caption)
                                .frame(width: 72, alignment: .trailing)
                            SecureField("留空复用 LLM API Key", text: $whisperAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                        HStack {
                            Text("Model:")
                                .font(.caption)
                                .frame(width: 72, alignment: .trailing)
                            TextField("whisper-1", text: $whisperAPIModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                        Text("留空 Base URL 和 API Key 将复用下方 LLM 设置")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 76)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }

    private func asrRadioRow(engine: ASREngineType, label: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: asrEngine == engine ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(asrEngine == engine ? Color.accentColor : Color.secondary)
                .font(.system(size: 14))
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            asrEngine = engine
        }
    }

    // MARK: - LLM Section

    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LLM Refinement")
                .font(.headline)

            Form {
                TextField("API Base URL:", text: $apiBaseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key:", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Model:", text: $model)
                    .textFieldStyle(.roundedBorder)
            }

            if !testResult.isEmpty {
                Text(testResult)
                    .font(.caption)
                    .foregroundStyle(testResult.contains("Success") ? .green : .red)
            }

            HStack {
                Button("Test LLM") {
                    testConnection()
                }
                .disabled(isTesting || apiBaseURL.isEmpty || apiKey.isEmpty || model.isEmpty)
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        HStack {
            Spacer()
            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func browseModel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.typeany/models")

        if panel.runModal() == .OK, let url = panel.url {
            whisperModelPath = url.path
            whisperModelExists = WhisperLocalEngine.modelExists(at: url.path)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = "Testing..."

        let prefs = PreferencesManager.shared
        let oldBase = prefs.llmAPIBaseURL
        let oldKey = prefs.llmAPIKey
        let oldModel = prefs.llmModel

        prefs.llmAPIBaseURL = apiBaseURL
        prefs.llmAPIKey = apiKey
        prefs.llmModel = model

        Task {
            do {
                let success = try await LLMRefiner().testConnection()
                await MainActor.run {
                    testResult = success ? "Success! Connection works." : "Failed: Server returned an error."
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Failed: \(error.localizedDescription)"
                    isTesting = false
                }
            }
            await MainActor.run {
                prefs.llmAPIBaseURL = oldBase
                prefs.llmAPIKey = oldKey
                prefs.llmModel = oldModel
            }
        }
    }

    private func save() {
        let prefs = PreferencesManager.shared
        // Trigger Key settings
        prefs.triggerKey = triggerKey
        prefs.customKeyCombo = customCombo
        onTriggerKeyChanged?()
        // ASR settings
        prefs.asrEngine = asrEngine
        prefs.whisperModelPath = whisperModelPath
        prefs.whisperAPIBaseURL = whisperAPIBaseURL
        prefs.whisperAPIKey = whisperAPIKey
        prefs.whisperAPIModel = whisperAPIModel
        // LLM settings
        prefs.llmAPIBaseURL = apiBaseURL
        prefs.llmAPIKey = apiKey
        prefs.llmModel = model
        onClose()
    }
}
