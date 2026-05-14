import AVFoundation
import Foundation

@MainActor
public final class AudioPreviewer: ObservableObject {
    @Published public private(set) var playingClipID: String?

    private var player: AVPlayer?

    public init() {}

    public func togglePreview(for clip: MemeClip) {
        if playingClipID == clip.id {
            stop()
            return
        }

        player?.pause()
        player = AVPlayer(url: clip.soundURL)
        playingClipID = clip.id
        player?.play()
    }

    public func stop() {
        player?.pause()
        player = nil
        playingClipID = nil
    }
}
