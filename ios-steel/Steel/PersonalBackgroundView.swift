import UIKit
import AVFoundation

/// Lightweight view that displays the shared background video or photo.
/// The actual AVQueuePlayer lives in BackgroundVideoManager singleton,
/// so video continues seamlessly across tab switches and modals.
final class PersonalBackgroundView: UIView {
    private let imageView = UIImageView()
    private let dimView = UIView()
    private var playerLayer: AVPlayerLayer?

    /// Current background kind (used by parent VCs to decide whether to show sound controls)
    private(set) var currentKind: BackgroundKind = .none

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
        // Remove old player layer (but don't stop the shared player!)
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        imageView.image = nil
        currentKind = config.kind

        switch config.kind {
        case .none:
            isHidden = true
            BackgroundVideoManager.shared.teardownIfActive()

        case .photo:
            isHidden = false
            // Tear down shared video player if switching from video to photo
            BackgroundVideoManager.shared.teardownIfActive()
            if let url = BackgroundManager.shared.fileURL(for: config),
               let data = try? Data(contentsOf: url) {
                imageView.image = UIImage(data: data)
            }
            dimView.isHidden = !config.dimmed

        case .video:
            isHidden = false
            imageView.image = nil
            // Setup shared player if needed (won't restart if same video)
            BackgroundVideoManager.shared.setupIfNeeded(fileName: config.fileName)

            // Create a player layer pointing to the shared player
            if let sharedPlayer = BackgroundVideoManager.shared.sharedPlayer {
                let layer = AVPlayerLayer(player: sharedPlayer)
                layer.videoGravity = .resizeAspectFill
                layer.frame = bounds
                self.layer.insertSublayer(layer, at: 0)
                self.playerLayer = layer
            }
            dimView.isHidden = !config.dimmed
        }
    }

    /// Called when view appears — ensures shared player is playing
    func resumeVideo() {
        BackgroundVideoManager.shared.play()
    }

    /// Called when view disappears — does NOT stop the shared player
    /// (video keeps running for seamless tab switching)
    func pauseVideo() {
        // Don't pause the shared player here!
        // It keeps running so the next tab can pick it up seamlessly.
        // Only pause if the app is going to background (handled separately).
    }
}
