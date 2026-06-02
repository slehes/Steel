import UIKit
import AVFoundation

final class PersonalBackgroundView: UIView {
    private let imageView = UIImageView()
    private let dimView = UIView()

    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

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
        teardownVideo()
        imageView.image = nil
        currentKind = config.kind

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
        queue.isMuted = DataManager.shared.settings.backgroundVideoMuted
        queue.volume = DataManager.shared.settings.backgroundVideoVolume
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

    // MARK: - Sound Control

    /// Whether the video player is currently muted
    var isMuted: Bool {
        return player?.isMuted ?? true
    }

    /// Current volume of the video player (0.0 ... 1.0)
    var volume: Float {
        return player?.volume ?? 0
    }

    /// Toggle mute with smooth fade animation
    func toggleMuted(animated: Bool = true) {
        guard let player else { return }
        let shouldMute = !player.isMuted
        let targetVolume: Float = shouldMute ? 0 : DataManager.shared.settings.backgroundVideoVolume

        if animated {
            fadeVolume(to: targetVolume, duration: 0.4) { [weak self] in
                self?.player?.isMuted = shouldMute
                if !shouldMute {
                    self?.player?.volume = DataManager.shared.settings.backgroundVideoVolume
                }
                DataManager.shared.updateSettings {
                    $0.backgroundVideoMuted = shouldMute
                }
            }
        } else {
            player.isMuted = shouldMute
            if !shouldMute {
                player.volume = DataManager.shared.settings.backgroundVideoVolume
            }
            DataManager.shared.updateSettings {
                $0.backgroundVideoMuted = shouldMute
            }
        }
    }

    /// Set volume with optional smooth fade
    func setVolume(_ newVolume: Float, animated: Bool = true) {
        guard let player else { return }
        let clamped = max(0, min(1, newVolume))

        if animated {
            fadeVolume(to: clamped, duration: 0.3) { [weak self] in
                guard let self, let player = self.player else { return }
                player.volume = clamped
                if clamped > 0 {
                    player.isMuted = false
                }
                DataManager.shared.updateSettings {
                    $0.backgroundVideoVolume = clamped
                    $0.backgroundVideoMuted = clamped == 0
                }
            }
        } else {
            player.volume = clamped
            if clamped > 0 {
                player.isMuted = false
            }
            DataManager.shared.updateSettings {
                $0.backgroundVideoVolume = clamped
                $0.backgroundVideoMuted = clamped == 0
            }
        }
    }

    /// Smoothly animate volume from current to target value
    private func fadeVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let player else {
            completion?()
            return
        }

        let startVolume = player.volume
        let startMuted = player.isMuted

        // If currently muted, unmute first and start from 0
        if startMuted {
            player.isMuted = false
            player.volume = 0
        }

        let effectiveStart = startMuted ? Float(0) : startVolume

        guard effectiveStart != target else {
            completion?()
            return
        }

        let startTime = CACurrentMediaTime()

        // Create a display link for smooth animation
        let displayLink = CADisplayLink(target: self, selector: #selector(volumeFadeStep))
        objc_setAssociatedObject(self, &AssociatedKeys.fadeCompletion, completion, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.fadeStartTime, startTime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.fadeDuration, duration, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.fadeStartVolume, effectiveStart, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.fadeTargetVolume, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        displayLink.add(to: .main, forMode: .common)
        objc_setAssociatedObject(self, &AssociatedKeys.fadeDisplayLink, displayLink, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc private func volumeFadeStep(_ link: CADisplayLink) {
        guard let player else {
            link.invalidate()
            return
        }

        let startTime = objc_getAssociatedObject(self, &AssociatedKeys.fadeStartTime) as? TimeInterval ?? 0
        let duration = objc_getAssociatedObject(self, &AssociatedKeys.fadeDuration) as? TimeInterval ?? 0.3
        let startVol = objc_getAssociatedObject(self, &AssociatedKeys.fadeStartVolume) as? Float ?? 0
        let targetVol = objc_getAssociatedObject(self, &AssociatedKeys.fadeTargetVolume) as? Float ?? 0

        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(1, Float(elapsed / duration))

        // Ease-in-out curve
        let eased = progress < 0.5
            ? 2 * progress * progress
            : 1 - pow(-2 * progress + 2, 2) / 2

        let currentVolume = startVol + (targetVol - startVol) * eased
        player.volume = max(0, min(1, currentVolume))

        if progress >= 1 {
            link.invalidate()
            player.volume = targetVol
            objc_setAssociatedObject(self, &AssociatedKeys.fadeDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let completion = objc_getAssociatedObject(self, &AssociatedKeys.fadeCompletion) as? (() -> Void)
            completion?()
        }
    }

    /// Cancel any ongoing fade animation
    func cancelFade() {
        if let link = objc_getAssociatedObject(self, &AssociatedKeys.fadeDisplayLink) as? CADisplayLink {
            link.invalidate()
            objc_setAssociatedObject(self, &AssociatedKeys.fadeDisplayLink, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Associated Keys for fade animation
private struct AssociatedKeys {
    nonisolated(unsafe) static var fadeCompletion: UInt8 = 0
    nonisolated(unsafe) static var fadeStartTime: UInt8 = 0
    nonisolated(unsafe) static var fadeDuration: UInt8 = 0
    nonisolated(unsafe) static var fadeStartVolume: UInt8 = 0
    nonisolated(unsafe) static var fadeTargetVolume: UInt8 = 0
    nonisolated(unsafe) static var fadeDisplayLink: UInt8 = 0
}
