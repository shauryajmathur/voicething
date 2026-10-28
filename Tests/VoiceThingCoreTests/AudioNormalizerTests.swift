import AVFoundation
import XCTest
@testable import VoiceThingCore

final class AudioNormalizerTests: XCTestCase {
    func testGainCalculationBoostsQuietAudioAndCutsLoudAudio() {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let quiet = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128)!
        quiet.frameLength = 128
        for index in 0..<128 {
            quiet.floatChannelData![0][index] = 0.02
        }

        let loud = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128)!
        loud.frameLength = 128
        for index in 0..<128 {
            loud.floatChannelData![0][index] = 0.8
        }

        let normalizer = AudioNormalizer()
        XCTAssertGreaterThan(normalizer.gainForNormalization(buffer: quiet), 1)
        XCTAssertLessThan(normalizer.gainForNormalization(buffer: loud), 1)
    }

    func testLargeClipUsesEveryChunkAndPreservesDuration() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source.caf")
        let output = folder.appendingPathComponent("normalized.m4a")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for channel in 0..<2 {
            for i in 0..<44100 { buffer.floatChannelData![channel][i] = sin(Float(i) * 0.1) * 0.9 }
        }
        do {
            let file = try AVAudioFile(forWriting: source, settings: format.settings)
            for _ in 0..<3 { try file.write(from: buffer) }
        }
        _ = try AudioNormalizer().normalizedFile(input: source, output: output)
        let normalized = try AVAudioFile(forReading: output)
        XCTAssertEqual(Double(normalized.length) / normalized.processingFormat.sampleRate, 3, accuracy: 0.1)
        XCTAssertLessThan(try output.resourceValues(forKeys: [.fileSizeKey]).fileSize!, 100000)
    }

    func testNormalizerWritesPlayableOutputFile() throws {
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410)!
        buffer.frameLength = 4_410
        for index in 0..<Int(buffer.frameLength) {
            buffer.floatChannelData![0][index] = 0.03
        }

        let inputFile = try AVAudioFile(forWriting: inputURL, settings: format.settings)
        try inputFile.write(from: buffer)

        let result = try AudioNormalizer().normalizedFile(input: inputURL, output: outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))

        let outputFile = try AVAudioFile(forReading: result)
        XCTAssertGreaterThan(outputFile.length, 0)
    }
}
