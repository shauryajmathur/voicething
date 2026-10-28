import AVFoundation
import Foundation

@MainActor
public final class AudioPreviewer: ObservableObject {
    @Published public private(set) var playingClipID: String?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    public init() {}

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    public func togglePreview(for clip: MemeClip) {
        if playingClipID == clip.id {
            stop()
            return
        }

        stop()
        let playerItem = AVPlayerItem(url: clip.soundURL)
        player = AVPlayer(playerItem: playerItem)
        playingClipID = clip.id

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }

        player?.play()
    }

    public func stop() {
        player?.pause()
        player = nil
        playingClipID = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
