import AVFoundation
import AudioToolbox
import CoreAudio

@MainActor
final class VoiceRecordingRoute {
    private var player: AVAudioPlayer?
    private var preparedFile: URL?
    private var previousInput: AudioDeviceID = 0
    private var device: AudioDeviceID = 0

    func prepare(file url: URL) throws {
        var uid: CFString = "com.voicething.audio.device" as CFString
        var found = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslateUIDToDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let result = withUnsafePointer(to: &uid) { uidPointer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<CFString>.size), uidPointer, &size, &found)
        }
        guard result == noErr, found != 0 else { throw RecordingError.routeUnavailable }
        device = found
        try resetVolume(on: found)
        let prepared = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceThing-Mic-\(UUID().uuidString).caf")
        preparedFile = prepared
        let normalizer = AudioNormalizer(settings: .init(targetRMS: 0.16, peakCeiling: 0.7, maxBoost: 4))
        _ = try normalizer.normalizedFile(input: url, output: prepared, lossless: true)
        let player = try AVAudioPlayer(contentsOf: prepared)
        player.volume = 1
        guard player.duration > 0, player.duration <= 60 else { throw AppError.instagramVoice("Choose a clip shorter than 60 seconds.") }
        player.currentDevice = "com.voicething.audio.device"
        self.player = player
        var output = found
        address.mSelector = kAudioHardwarePropertyDefaultInputDevice
        size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &previousInput) == noErr else { throw RecordingError.routeUnavailable }
        guard AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &output) == noErr else { throw RecordingError.routeUnavailable }
        guard player.prepareToPlay() else { stop(); throw AppError.instagramVoice("Could not prepare the sound for Instagram.") }
    }

    func play(check: () throws -> Void) async throws {
        try check()
        guard let player, player.play() else { throw AppError.instagramVoice("Could not play the sound into Instagram.") }
        let deadline = Date().addingTimeInterval(player.duration + 3)
        while player.isPlaying {
            try Task.checkCancellation()
            try check()
            guard Date() < deadline else { throw AppError.instagramVoice("Audio playback timed out.") }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func resetVolume(on device: AudioDeviceID) throws {
        for scope in [kAudioObjectPropertyScopeInput, kAudioObjectPropertyScopeOutput] {
            // Driver v1 applies the stored scalar as dB, so zero gives unity gain.
            var volume = Float32(0)
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: scope, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume) == noErr else {
                throw AppError.instagramVoice("Could not set the virtual microphone volume.")
            }
            var mute = UInt32(0)
            address.mSelector = kAudioDevicePropertyMute
            guard AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &mute) == noErr else {
                throw AppError.instagramVoice("Could not unmute the virtual microphone.")
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if let preparedFile { try? FileManager.default.removeItem(at: preparedFile) }
        preparedFile = nil
        if previousInput != 0, device != 0 {
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var current = AudioDeviceID(0)
            if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &current) == noErr, current == device {
                var restore = previousInput
                _ = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &restore)
            }
        }
        previousInput = 0
        device = 0
    }
}
