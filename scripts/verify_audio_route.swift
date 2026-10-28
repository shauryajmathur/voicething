import AppKit
import AVFoundation
import Foundation

enum RecordingError: Error { case microphoneDenied, routeUnavailable, couldNotRecord }

@main
struct VerifyVoiceThingAudio {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            let report: [String: Any]
            do { report = try await verify() }
            catch { report = ["passed": false, "error": error.localizedDescription] }
            let output = URL(fileURLWithPath: CommandLine.arguments[1])
            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: output, options: .atomic)
            } catch { NSLog("Could not write audio verification: %@", error.localizedDescription) }
            app.terminate(nil)
        }
        app.run()
    }

    @MainActor static func verify() async throws -> [String: Any] {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw RecordingError.microphoneDenied }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceThingAudioCheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("tone.caf")
        let captured = directory.appendingPathComponent("captured.m4a")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for channel in 0..<2 {
            for frame in 0..<44100 { buffer.floatChannelData![channel][frame] = (CommandLine.arguments.count > 2 ? Float(CommandLine.arguments[2]) ?? 0.25 : 0.25) * sin(2 * .pi * 997 * Float(frame) / 44100) }
        }
        do { let file = try AVAudioFile(forWriting: input, settings: format.settings); try file.write(from: buffer) }
        
        let route = VoiceRecordingRoute()
        defer { route.stop() }
        try route.prepare(file: input)
        let recorder = try AVAudioRecorder(url: captured, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96000])
        guard recorder.record() else { throw RecordingError.couldNotRecord }
        defer { recorder.stop() }
        try await Task.sleep(for: .milliseconds(600))
        try await route.play(check: {})
        try await Task.sleep(for: .milliseconds(300))
        recorder.stop()
        let result = try AVAudioFile(forReading: captured)
        let data = AVAudioPCMBuffer(pcmFormat: result.processingFormat, frameCapacity: AVAudioFrameCount(result.length))!
        try result.read(into: data)
        guard let samples = data.floatChannelData?[0] else { throw RecordingError.couldNotRecord }
        var energy: Double = 0, sine: Double = 0, cosine: Double = 0
        let count = Int(data.frameLength)
        for frame in 0..<count {
            let value = Double(samples[frame])
            let phase = 2 * Double.pi * 997 * Double(frame) / result.processingFormat.sampleRate
            energy += value * value
            sine += value * sin(phase)
            cosine += value * cos(phase)
        }
        let rms = count > 0 ? sqrt(energy / Double(count)) : 0
        let toneFraction = energy > 0 ? 2 * (sine * sine + cosine * cosine) / (Double(count) * energy) : 0
        let window = min(4410, count)
        var bestRMS = 0.0, bestPurity = 0.0, peak = 0.0
        if window > 0 {
            for start in stride(from: 0, through: count - window, by: window) {
                var power = 0.0, real = 0.0, imaginary = 0.0
                for frame in start..<(start + window) {
                    let value = Double(samples[frame])
                    peak = max(peak, abs(value))
                    let phase = 2 * Double.pi * 997 * Double(frame) / result.processingFormat.sampleRate
                    power += value * value
                    real += value * sin(phase)
                    imaginary += value * cos(phase)
                }
                let level = sqrt(power / Double(window))
                if level > bestRMS {
                    bestRMS = level
                    bestPurity = power > 0 ? 2 * (real * real + imaginary * imaginary) / (Double(window) * power) : 0
                }
            }
        }
        return ["passed": bestRMS > 0.1 && bestPurity > 0.98 && peak < 0.95,
                "activeRMS": bestRMS, "activeTonePurity": bestPurity, "peak": peak, "device": "VoiceThing Microphone",
                "duration": Double(count) / result.processingFormat.sampleRate, "rms": rms,
                "toneEnergyFraction": toneFraction, "testFrequency": 997,
                "capturedWith": "AVAudioRecorder through system input", "speakerPlayback": false]
    }
}
