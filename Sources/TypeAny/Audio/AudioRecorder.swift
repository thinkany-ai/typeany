import AVFoundation
import Combine

final class AudioRecorder {
    let audioLevelSubject = PassthroughSubject<Float, Never>()
    let audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()

    private var audioEngine: AVAudioEngine?
    private var isRecording = false

    // WAV recording for Whisper engines
    private var wavFile: AVAudioFile?
    private var wavConverter: AVAudioConverter?
    private var wavURL: URL?
    private let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: 16000, channels: 1,
                                              interleaved: false)!

    func startRecording(recordWAV: Bool = false) {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Setup WAV file if needed
        if recordWAV {
            setupWAVFile(inputFormat: format)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Compute RMS level
            let level = self.computeRMS(buffer: buffer)
            DispatchQueue.main.async {
                self.audioLevelSubject.send(level)
            }
            // Forward buffer for speech recognition
            self.audioBufferSubject.send(buffer)
            // Write to WAV if recording
            self.writeToWAV(buffer: buffer)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            isRecording = true
        } catch {
            print("[TypeAny] Failed to start audio engine: \(error)")
        }
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        // Finalize WAV
        let url = wavURL
        wavFile = nil
        wavConverter = nil
        wavURL = nil

        DispatchQueue.main.async {
            self.audioLevelSubject.send(0)
        }
        return url
    }

    // MARK: - WAV Recording

    private func setupWAVFile(inputFormat: AVAudioFormat) {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("typeany_\(UUID().uuidString).wav")
        self.wavURL = url

        do {
            wavFile = try AVAudioFile(forWriting: url, settings: whisperFormat.settings)
            if inputFormat.sampleRate != whisperFormat.sampleRate ||
               inputFormat.channelCount != whisperFormat.channelCount {
                wavConverter = AVAudioConverter(from: inputFormat, to: whisperFormat)
            }
        } catch {
            print("[TypeAny] Failed to create WAV file: \(error)")
            wavFile = nil
        }
    }

    private func writeToWAV(buffer: AVAudioPCMBuffer) {
        guard let wavFile = wavFile else { return }

        if let converter = wavConverter {
            // Need to convert format
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * whisperFormat.sampleRate / buffer.format.sampleRate
            )
            guard frameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat,
                                                          frameCapacity: frameCapacity) else { return }

            var error: NSError?
            var hasData = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if hasData {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                hasData = true
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil && convertedBuffer.frameLength > 0 {
                do {
                    try wavFile.write(from: convertedBuffer)
                } catch {
                    print("[TypeAny] WAV write error: \(error)")
                }
            }
        } else {
            // Same format, write directly
            do {
                try wavFile.write(from: buffer)
            } catch {
                print("[TypeAny] WAV write error: \(error)")
            }
        }
    }

    private func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<count {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))
        // Convert to 0-1 range with some amplification
        let normalized = min(rms * 5.0, 1.0)
        return normalized
    }
}
