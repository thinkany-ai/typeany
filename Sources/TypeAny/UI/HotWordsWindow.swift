import SwiftUI
import Cocoa

final class HotWordsWindowController {
    private var window: NSWindow?

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HotWordsView { [weak self] in
            self?.window?.close()
            self?.window = nil
        }

        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "TypeAny - Hot Words"
        window.setContentSize(NSSize(width: 480, height: 400))
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 400, height: 300)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}

struct HotWordsView: View {
    let onClose: () -> Void
    @State private var words: [(from: String, to: String)] = []
    @State private var newFrom: String = ""
    @State private var newTo: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Hot Words")
                .font(.headline)

            Text("Speech recognition corrections. These apply even without LLM.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Add new pair
            HStack(spacing: 8) {
                TextField("Wrong (e.g. 配森)", text: $newFrom)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)

                Text("→")
                    .foregroundStyle(.secondary)

                TextField("Correct (e.g. Python)", text: $newTo)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)

                Button("Add") {
                    addWord()
                }
                .disabled(newFrom.isEmpty || newTo.isEmpty)
            }
            .padding(.horizontal)

            Divider()

            // List of existing hot words
            if words.isEmpty {
                Spacer()
                Text("No hot words configured")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, pair in
                        HStack {
                            Text(pair.from)
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(minWidth: 80, alignment: .trailing)
                            Text("→")
                                .foregroundStyle(.secondary)
                            Text(pair.to)
                                .foregroundStyle(.green.opacity(0.8))
                                .frame(minWidth: 80, alignment: .leading)
                            Spacer()
                            Button(role: .destructive) {
                                removeWord(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack {
                Button("Close") {
                    onClose()
                }
            }
            .padding(.bottom, 8)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            loadWords()
        }
    }

    private func addWord() {
        let from = newFrom.trimmingCharacters(in: .whitespaces)
        let to = newTo.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        HotWordsManager.shared.addHotWord(from: from, to: to)
        newFrom = ""
        newTo = ""
        loadWords()
    }

    private func removeWord(at index: Int) {
        HotWordsManager.shared.removeHotWord(at: index)
        loadWords()
    }

    private func loadWords() {
        words = HotWordsManager.shared.hotWords
    }
}
