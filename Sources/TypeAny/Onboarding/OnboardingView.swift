import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(current: model.step)
            HStack(spacing: 0) {
                LeftPane(model: model)
                    .frame(width: 540)
                    .frame(maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                RightPane(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .ignoresSafeArea()
        .frame(minWidth: 1000, minHeight: 680)
        .tint(Brand.color)
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }
}

// MARK: - Header

private struct StepHeader: View {
    let current: OnboardingModel.Step

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ForEach(OnboardingModel.Step.allCases, id: \.self) { step in
                    Text(step.title)
                        .font(.system(size: 14, weight: step == current ? .semibold : .regular))
                        .foregroundStyle(step == current ? Color.primary
                                         : step.rawValue < current.rawValue ? Color.secondary : Color.secondary.opacity(0.6))
                    if step != OnboardingModel.Step.allCases.last {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.top, 2)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.06))
                    Rectangle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var progress: CGFloat {
        CGFloat(current.rawValue + 1) / CGFloat(OnboardingModel.Step.allCases.count)
    }
}

// MARK: - Left Pane

private struct LeftPane: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: model.back) {
                Label("返回", systemImage: "arrow.left")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(model.step == .welcome ? 0 : 1)
            .disabled(model.step == .welcome)

            Spacer(minLength: 32)

            Group {
                switch model.step {
                case .welcome: WelcomeContent(triggerKey: model.triggerKeyLabel)
                case .permissions: PermissionsContent(model: model)
                case .inputMethod: InputMethodContent(model: model)
                case .voice: VoiceContent(model: model)
                case .translate: TranslateContent(model: model)
                }
            }
            .id(model.step)
            .transition(.opacity.combined(with: .offset(x: 12)))

            Spacer(minLength: 32)

            HStack {
                Spacer()
                PrimaryButton(title: primaryTitle, action: model.next)
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 36)
        .padding(.bottom, 40)
    }

    private var primaryTitle: String {
        switch model.step {
        case .welcome: return "开始设置"
        case .permissions: return model.allPermissionsGranted ? "继续" : "跳过"
        case .translate: return "完成"
        default: return "继续"
        }
    }
}

private struct StepTitle: View {
    let title: String
    var key: String?
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 34, weight: .bold))
                if let key = key {
                    KeyCap(label: key, size: 20)
                }
            }
            Text(subtitle)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WelcomeContent: View {
    let triggerKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            StepTitle(title: "欢迎使用 TypeAny", subtitle: "会听、会写，还能帮你翻译的输入法。")
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "waveform", title: "语音输入",
                           detail: "按住 \(triggerKey) 说话，文字实时出现在光标处。")
                FeatureRow(icon: "keyboard", title: "拼音输入",
                           detail: "雾凇词库，整句、简拼都顺手，还会记住你的用词。")
                FeatureRow(icon: "globe", title: "中文写，英文发",
                           detail: "回复英文推文时用中文写，回车就是地道的英文。")
            }
            Text("接下来花一分钟完成设置。")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Brand.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Brand.color.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PermissionsContent: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepTitle(title: "授予权限", subtitle: "TypeAny 只在你按住快捷键时录音，权限仅用于输入。")
            VStack(spacing: 10) {
                ChecklistRow(icon: "mic", title: "麦克风", detail: "录下你说的话",
                             done: model.micGranted, actionTitle: "授权", action: model.requestMicrophone)
                ChecklistRow(icon: "text.bubble", title: "语音识别", detail: "把语音转成文字",
                             done: model.speechGranted, actionTitle: "授权", action: model.requestSpeech)
                ChecklistRow(icon: "accessibility", title: "辅助功能",
                             detail: "监听 \(model.triggerKeyLabel) 快捷键；在系统设置里打开 TypeAny 的开关",
                             done: model.accessibilityGranted, actionTitle: "去开启",
                             action: model.requestAccessibility)
            }
            if !model.allPermissionsGranted {
                Text("授权后这里会自动更新。")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct InputMethodContent: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepTitle(title: "启用输入法", subtitle: "切换到 TypeAny 后，就能打拼音、说话和翻译。")
            VStack(spacing: 10) {
                ChecklistRow(icon: "plus.rectangle.on.rectangle", title: "添加到输入法列表",
                             detail: "出现在菜单栏的输入法菜单里",
                             done: model.imeEnabled, actionTitle: "添加", action: model.enableInputMethod)
                ChecklistRow(icon: "character.cursor.ibeam", title: "切换到 TypeAny 拼音",
                             detail: "设为当前输入法",
                             done: model.imeSelected, actionTitle: "切换", action: model.selectInputMethod)
                    .disabled(!model.imeEnabled)
                    .opacity(model.imeEnabled ? 1 : 0.5)
            }
            HStack(spacing: 6) {
                Text("以后可以用")
                KeyCap(label: "⌃ 空格", size: 12)
                Text("或")
                KeyCap(label: "🌐", size: 12)
                Text("在输入法之间切换。")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
    }
}

private struct VoiceContent: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepTitle(title: "语音输入", key: model.triggerKeyLabel, subtitle: "把想说的话直接说进输入框。")
            InstructionCard(icon: "mic") {
                Text("点击右侧输入框，按住 ") + Text(model.triggerKeyLabel).bold()
                    + Text(" 读出下面这句话，说完松开。")
            } quote: {
                "下午的会我可能要晚到十分钟，你们先开始，我到了再同步一下进度。"
            }
            ReadinessHint(model: model, needsPermissions: true)
        }
    }
}

private struct TranslateContent: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepTitle(title: "中文写，英文发", key: "⌃⇧T",
                      subtitle: "回复英文推文时用中文写，TypeAny 帮你翻成地道的英文。")
            InstructionCard(icon: "globe") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 点击右侧回复框，按 ") + Text("⌃⇧T").bold() + Text(" 开启翻译模式")
                    Text("2. 用拼音或语音写中文回复，比如：")
                    Text("3. 看到英文预览后按 ") + Text("回车").bold() + Text(" 发出（") + Text("⌥回车").bold()
                        + Text(" 保留中文）")
                }
            } quote: {
                "离不开的工具肯定是 Raycast，每天打开几百次"
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("翻译服务").font(.system(size: 14, weight: .semibold))
                SecureField("OpenAI 兼容 API Key（可选）", text: $model.apiKey)
                    .textFieldStyle(.roundedBorder)
                Text(model.apiKey.isEmpty
                     ? "不填时使用 Apple 本地翻译：需在 系统设置 → 通用 → 语言与地区 → 翻译语言 下载中文和英语。"
                     : "使用大模型翻译，地址和模型可在菜单栏 TypeAny → Settings 修改。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReadinessHint(model: model, needsPermissions: false)
        }
    }
}

/// Explains why the practice field may not respond yet
private struct ReadinessHint: View {
    @ObservedObject var model: OnboardingModel
    let needsPermissions: Bool

    var body: some View {
        if !model.imeSelected {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text("当前输入法不是 TypeAny")
                Button("切换") { model.selectInputMethod() }
                    .buttonStyle(.link)
            }
            .font(.system(size: 13))
        } else if needsPermissions && !model.allPermissionsGranted {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text("还有权限没开，语音可能无法使用")
                Button("去授权") { model.step = .permissions }
                    .buttonStyle(.link)
            }
            .font(.system(size: 13))
        }
    }
}

// MARK: - Components

private struct KeyCap: View {
    let label: String
    var size: CGFloat = 15

    var body: some View {
        Text(label)
            .font(.system(size: size, weight: .semibold))
            .padding(.horizontal, size * 0.4)
            .padding(.vertical, size * 0.12)
            .background(RoundedRectangle(cornerRadius: size * 0.28).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(Color.primary.opacity(0.3), lineWidth: 1))
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.primary))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}

private struct ChecklistRow: View {
    let icon: String
    let title: String
    let detail: String
    let done: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
    }
}

private struct InstructionCard<Instruction: View>: View {
    let icon: String
    @ViewBuilder let instruction: Instruction
    let quote: () -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Brand.color)
                    .padding(.top, 1)
                instruction
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)

            Divider().opacity(0.5)

            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.4)).frame(width: 2)
                Text(quote())
                    .font(.system(size: 19, weight: .semibold))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)  // keep the quote bar from stretching
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.035)))
    }
}

// MARK: - Right Pane

private struct RightPane: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        ZStack {
            Backdrop()
            Group {
                switch model.step {
                case .welcome: WelcomeVisual()
                case .permissions: PermissionsVisual(model: model)
                case .inputMethod: InputMenuVisual(selected: model.imeSelected)
                case .voice: VoicePractice(model: model)
                case .translate: TranslatePractice(model: model)
                }
            }
            .id(model.step)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .padding(36)
        }
        .environment(\.colorScheme, .light)
    }
}

private struct Backdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.88, green: 0.97, blue: 0.95),
                                    Color(red: 0.96, green: 0.97, blue: 0.97)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Brand.color.opacity(0.28))
                .frame(width: 360).blur(radius: 90).offset(x: 140, y: -220)
            Circle().fill(Color(red: 0.62, green: 0.90, blue: 0.85).opacity(0.35))
                .frame(width: 320).blur(radius: 90).offset(x: -160, y: 240)
        }
    }
}

private struct AppCard<Icon: View, Content: View>: View {
    let name: String
    @ViewBuilder let icon: Icon
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                icon.frame(width: 22, height: 22)
                Text(name).font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.97))

            Divider()

            VStack(alignment: .leading, spacing: 16) { content }
                .padding(18)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
    }
}

private struct Avatar: View {
    let letter: String
    let color: Color

    var body: some View {
        Text(letter)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.gradient))
    }
}

private struct PracticeEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(8)
            // Hidden while focused: marked text (pinyin / voice) isn't in `text` yet and would overlap
            if text.isEmpty && !focused {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.black.opacity(0.3))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 140)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(focused ? Brand.color.opacity(0.6) : Color.black.opacity(0.12), lineWidth: focused ? 2 : 1))
        .onAppear {
            // Focus so the TypeAny input method attaches to this field right away
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }
}

private struct Checklist: View {
    let items: [String]
    let visible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Label {
                    Text(item).font(.system(size: 17, weight: .semibold))
                } icon: {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                }
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 6)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.15), value: visible)
            }
        }
        .foregroundStyle(Color.black.opacity(0.8))
        .padding(.horizontal, 6)
    }
}

private struct VoicePractice: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            AppCard(name: "Slack") {
                Image(systemName: "number.square.fill")
                    .resizable()
                    .foregroundStyle(Color(red: 0.29, green: 0.08, blue: 0.29))
            } content: {
                HStack(alignment: .top, spacing: 12) {
                    Avatar(letter: "A", color: .pink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anna").font(.system(size: 15, weight: .semibold))
                        Text("下午的会还开吗？大家快到齐了").font(.system(size: 15)).foregroundStyle(.secondary)
                    }
                }
                PracticeEditor(text: $model.voiceText, placeholder: "点这里，按住 \(model.triggerKeyLabel) 说话…")
            }
            Checklist(items: ["边说边出字，不用干等", "松开快捷键就上屏", "任何 App 的输入框都能用"],
                      visible: !model.voiceText.isEmpty)
        }
        .frame(maxWidth: 480)
    }
}

private struct TranslatePractice: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            AppCard(name: "X") {
                Text("𝕏")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.black))
            } content: {
                HStack(alignment: .top, spacing: 12) {
                    Avatar(letter: "S", color: .blue)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Sam").font(.system(size: 15, weight: .semibold))
                            Text("@sam · 2h").font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                        Text("What's one tool you can't live without these days?")
                            .font(.system(size: 15))
                    }
                }
                Text("回复 @sam").font(.system(size: 13)).foregroundStyle(.secondary)
                PracticeEditor(text: $model.translateText, placeholder: "按 ⌃⇧T，然后用中文写回复…")
            }
            Checklist(items: ["用中文写，发出去是英文", "像母语者一样的推特语气", "@提及和 #话题 原样保留"],
                      visible: model.translateSucceeded)
        }
        .frame(maxWidth: 480)
    }
}

private struct WelcomeVisual: View {
    var body: some View {
        VStack(spacing: 22) {
            AppIconImage(size: 168)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            Text("TypeAny").font(.system(size: 28, weight: .bold))
            HStack(spacing: 10) {
                ForEach(["说", "打", "译"], id: \.self) { word in
                    Text(word)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                }
            }
        }
    }
}

private struct PermissionsVisual: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        AppCard(name: "隐私与安全性") {
            Image(systemName: "hand.raised.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Brand.color)
        } content: {
            VStack(spacing: 0) {
                ToggleRow(title: "麦克风", on: model.micGranted)
                Divider()
                ToggleRow(title: "语音识别", on: model.speechGranted)
                Divider()
                ToggleRow(title: "辅助功能", on: model.accessibilityGranted)
            }
        }
        .frame(maxWidth: 420)
    }

    private struct ToggleRow: View {
        let title: String
        let on: Bool

        var body: some View {
            HStack {
                AppIconImage(size: 30)
                Text("TypeAny").font(.system(size: 14))
                Text("· \(title)").font(.system(size: 14)).foregroundStyle(.secondary)
                Spacer()
                Capsule()
                    .fill(on ? Color.green : Color.black.opacity(0.12))
                    .frame(width: 38, height: 22)
                    .overlay(Circle().fill(.white).padding(2).offset(x: on ? 8 : -8))
                    .animation(.spring(duration: 0.3), value: on)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct InputMenuVisual: View {
    let selected: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 14) {
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Group {
                    if selected {
                        MarkImage().frame(width: 16, height: 16)
                    } else {
                        Text("微").font(.system(size: 12, weight: .bold))
                    }
                }
                .frame(width: 20, height: 18)
                Text("10:24").font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.7)))

            VStack(alignment: .leading, spacing: 2) {
                MenuRow(title: "ABC", checked: false)
                MenuRow(title: "微信输入法", checked: !selected)
                MenuRow(title: "TypeAny 拼音", checked: selected, highlighted: true)
                Divider().padding(.vertical, 4)
                MenuRow(title: "打开键盘设置…", checked: false)
            }
            .padding(6)
            .frame(width: 260)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
    }

    private struct MenuRow: View {
        let title: String
        let checked: Bool
        var highlighted = false

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(checked ? 1 : 0)
                Text(title).font(.system(size: 14))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 6).fill(highlighted ? Brand.color : .clear))
        }
    }
}

// MARK: - Brand

/// The bundle's app icon (AppIcon.icns)
struct AppIconImage: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

/// Monochrome TypeAny mark (TypeAny.pdf), tinted with the current foreground style
struct MarkImage: View {
    var body: some View {
        if let image = NSImage(named: "TypeAny") {
            Image(nsImage: image).resizable().renderingMode(.template).scaledToFit()
        }
    }
}
