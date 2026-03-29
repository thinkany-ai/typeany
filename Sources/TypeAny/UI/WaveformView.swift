import SwiftUI

struct WaveformView: View {
    let audioLevel: Float

    // Bar weights: center-high, sides-low
    private let barWeights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let barCount = 5
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3

    @State private var smoothedLevels: [CGFloat] = Array(repeating: 0.05, count: 5)
    @State private var jitterOffsets: [CGFloat] = Array(repeating: 0, count: 5)

    // Smoothing parameters
    private let attackRate: CGFloat = 0.40
    private let releaseRate: CGFloat = 0.15
    private let jitterAmount: CGFloat = 0.04

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                let totalBarsWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
                let startX = (size.width - totalBarsWidth) / 2
                let maxHeight = size.height - 4

                for i in 0..<barCount {
                    let x = startX + CGFloat(i) * (barWidth + barSpacing)
                    let barHeight = max(4, smoothedLevels[i] * maxHeight)
                    let y = (size.height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                    context.fill(path, with: .color(.white.opacity(0.9)))
                }
            }
            .onChange(of: audioLevel) { _, newLevel in
                updateLevels(CGFloat(newLevel))
            }
        }
        .onAppear {
            smoothedLevels = Array(repeating: 0.05, count: barCount)
        }
    }

    private func updateLevels(_ level: CGFloat) {
        for i in 0..<barCount {
            let target = level * barWeights[i]
            // Add random jitter for organic feel
            let jitter = CGFloat.random(in: -jitterAmount...jitterAmount)
            let targetWithJitter = max(0.05, min(1.0, target + jitter))

            let current = smoothedLevels[i]
            if targetWithJitter > current {
                // Attack: fast rise
                smoothedLevels[i] = current + (targetWithJitter - current) * attackRate
            } else {
                // Release: slow fall
                smoothedLevels[i] = current + (targetWithJitter - current) * releaseRate
            }
        }
    }
}
