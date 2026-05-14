import AVFoundation
import Foundation

public final class AudioNormalizer {
    public struct Settings {
        public let targetRMS: Float
        public let peakCeiling: Float
        public let maxBoost: Float
        public let maxCut: Float

        public init(
            targetRMS: Float = 0.16,
            peakCeiling: Float = 0.93,
            maxBoost: Float = 4.0,
            maxCut: Float = 0.25
        ) {
            self.targetRMS = targetRMS
            self.peakCeiling = peakCeiling
            self.maxBoost = maxBoost
            self.maxCut = maxCut
        }
    }

    private let settings: Settings

    public init(settings: Settings = Settings()) {
        self.settings = settings
    }

    public func normalizedFile(input: URL, output: URL) throws -> URL {
        let file = try AVAudioFile(forReading: input)
        let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: file.processingFormat.sampleRate,
            channels: file.processingFormat.channelCount,
            interleaved: false
        ) ?? file.processingFormat

        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AppError.normalizationFailed
        }

        try file.read(into: buffer)
        let gain = gainForNormalization(buffer: buffer)
        applyGain(gain, to: buffer)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: processingFormat.sampleRate,
            AVNumberOfChannelsKey: Int(processingFormat.channelCount),
            AVEncoderBitRateKey: 96_000
        ]

        let outputDirectory = output.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        let outputFile = try AVAudioFile(forWriting: output, settings: outputSettings)
        try outputFile.write(from: buffer)
        return output
    }

    public func gainForNormalization(buffer: AVAudioPCMBuffer) -> Float {
        let stats = audioStats(buffer: buffer)
        guard stats.rms > 0 else { return 1 }

        let rmsGain = settings.targetRMS / stats.rms
        let peakGain = stats.peak > 0 ? settings.peakCeiling / stats.peak : settings.maxBoost
        let unclippedGain = min(rmsGain, peakGain)
        return min(max(unclippedGain, settings.maxCut), settings.maxBoost)
    }

    private func applyGain(_ gain: Float, to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for index in 0..<frameLength {
                samples[index] = max(-settings.peakCeiling, min(settings.peakCeiling, samples[index] * gain))
            }
        }
    }

    private func audioStats(buffer: AVAudioPCMBuffer) -> (rms: Float, peak: Float) {
        guard let channelData = buffer.floatChannelData else { return (0, 0) }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var sumSquares: Double = 0
        var sampleCount = 0
        var peak: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for index in 0..<frameLength {
                let sample = samples[index]
                let absolute = abs(sample)
                peak = max(peak, absolute)
                sumSquares += Double(sample * sample)
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return (0, 0) }
        return (Float(sqrt(sumSquares / Double(sampleCount))), peak)
    }
}
