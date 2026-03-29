import Cocoa
import SwiftUI
import Combine

final class FloatingPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingPanelContent>?
    private let appState = AppState.shared
    private var contentModel = FloatingPanelModel()
    private var cancellables = Set<AnyCancellable>()

    func show() {
        guard panel == nil else { return }

        contentModel.transcription = ""
        contentModel.audioLevel = 0
        contentModel.statusText = nil

        let content = FloatingPanelContent(model: contentModel)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 240, height: 56)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 56),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden

        // Remove all title bar buttons
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.contentView = hosting
        self.hostingView = hosting
        self.panel = panel

        // Subscribe to state changes
        appState.$currentTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.contentModel.transcription = text
                self?.updatePanelSize()
            }
            .store(in: &cancellables)

        appState.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.contentModel.audioLevel = level
            }
            .store(in: &cancellables)

        // Position at bottom center of screen
        positionPanel(panel, width: 240)

        // Entrance animation
        panel.alphaValue = 0
        panel.setFrame(
            NSRect(x: panel.frame.origin.x, y: panel.frame.origin.y - 20,
                   width: panel.frame.width, height: panel.frame.height),
            display: false
        )
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(
                NSRect(x: panel.frame.origin.x, y: panel.frame.origin.y + 20,
                       width: panel.frame.width, height: panel.frame.height),
                display: true
            )
        }
    }

    func showTranscribing() {
        contentModel.statusText = "Transcribing..."
        contentModel.showSuccess = false
    }

    func showRefining() {
        contentModel.statusText = "Refining..."
        contentModel.showSuccess = false
    }

    func showSuccess() {
        contentModel.statusText = nil
        contentModel.showSuccess = true
    }

    func showVADHint() {
        contentModel.vadBlinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.contentModel.vadBlinking = false
        }
    }

    func hide() {
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            let frame = panel.frame
            panel.animator().setFrame(
                NSRect(x: frame.origin.x + frame.width * 0.05,
                       y: frame.origin.y + frame.height * 0.05,
                       width: frame.width * 0.9,
                       height: frame.height * 0.9),
                display: true
            )
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
            self?.hostingView = nil
            self?.cancellables.removeAll()
            self?.contentModel.statusText = nil
        })
    }

    private func updatePanelSize() {
        guard let panel = panel else { return }

        let text = contentModel.transcription
        let font = NSFont.systemFont(ofSize: 14)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        // 68 for waveform area + padding, clamp label width 160-560
        let labelWidth = max(160, min(textWidth + 20, 560))
        let totalWidth = 68 + labelWidth + 16

        let newFrame = NSRect(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y,
            width: totalWidth,
            height: 56
        )

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            // Re-center horizontally
            if let screen = NSScreen.main {
                let x = (screen.frame.width - totalWidth) / 2
                panel.animator().setFrame(
                    NSRect(x: x, y: newFrame.origin.y, width: totalWidth, height: 56),
                    display: true
                )
            } else {
                panel.animator().setFrame(newFrame, display: true)
            }
        }
    }

    private func positionPanel(_ panel: NSPanel, width: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = (screenFrame.width - width) / 2 + screenFrame.origin.x
        let y = screenFrame.origin.y + 60 // 60px from bottom
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI Content

final class FloatingPanelModel: ObservableObject {
    @Published var transcription: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var statusText: String? = nil
    @Published var showSuccess: Bool = false
    @Published var vadBlinking: Bool = false
}

struct FloatingPanelContent: View {
    @ObservedObject var model: FloatingPanelModel

    var body: some View {
        HStack(spacing: 12) {
            if model.showSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                WaveformView(audioLevel: model.audioLevel)
                    .frame(width: 44, height: 32)
                    .opacity(model.vadBlinking ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: model.vadBlinking)
            }

            if model.showSuccess {
                Text("Done")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(minWidth: 60, alignment: .leading)
            } else if let status = model.statusText {
                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 80, alignment: .leading)
            } else {
                Text(model.transcription.isEmpty ? "Listening..." : model.transcription)
                    .font(.system(size: 14))
                    .foregroundStyle(model.transcription.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(minWidth: 160, maxWidth: 560, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background {
            VisualEffectBackground()
                .clipShape(Capsule())
        }
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: model.showSuccess)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 28
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
