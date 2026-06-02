import UIKit
import AVFoundation

final class PersonalBackgroundView: UIView {
    private let imageView = UIImageView()
    private let dimView = UIView()

    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        dimView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.55)
        addSubview(dimView)
        imageView.pinEdges(to: self)
        dimView.pinEdges(to: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func apply(_ config: BackgroundConfig) {
        teardownVideo()
        imageView.image = nil

        switch config.kind {
        case .none:
            isHidden = true
            return
        case .photo:
            isHidden = false
            if let url = BackgroundManager.shared.fileURL(for: config),
               let data = try? Data(contentsOf: url) {
                imageView.image = UIImage(data: data)
            }
            dimView.isHidden = !config.dimmed
        case .video:
            isHidden = false
            if let url = BackgroundManager.shared.fileURL(for: config) {
                setupVideo(url: url)
            }
            dimView.isHidden = !config.dimmed
        }
    }

    private func setupVideo(url: URL) {
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: item)
        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        self.playerLayer = layer
        self.player = queue
        queue.play()
    }

    private func teardownVideo() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        looper = nil
    }

    func pauseVideo() { player?.pause() }
    func resumeVideo() { player?.play() }
}
