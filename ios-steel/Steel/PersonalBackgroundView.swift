import UIKit
import AVFoundation

final class PersonalBackgroundView: UIView {
    private let imageView = UIImageView()
    private let dimView = UIView()

    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var videoURL: URL?

    /// Current background kind (used by parent VCs to decide whether to show sound controls)
    private(set) var currentKind: BackgroundKind = .none

    // Fade animation state
    private var fadeDisplayLink: CADisplayLink?
    private var fadeStartTime: TimeInterval = 0
    private var fadeDuration: TimeInterval = 0.3
    private var fadeStartVolume: Float = 0
    private var fadeTargetVolume: Float = 0
    private var fadeCompletion: (() -> Void)?

    /// The intended mute state — set immediately on toggle, used for icon display.
    /// During fade animation, the real player state is in transition, so we use this instead.
    private(set) var intendedMuted: Bool = true

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

        // Observe video end as fallback for looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
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
        // Configure audio session so video sound is audible
        configureAudioSession()

        self.videoURL = url
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)

        // Apply saved sound settings
        let savedMuted = DataManager.shared.settings.backgroundVideoMuted
        let savedVolume = DataManager.shared.settings.backgroundVideoVolume
        queue.isMuted = savedMuted
        queue.volume = savedMuted ? 0 : savedVolume
        intendedMuted = savedMuted

        // Setup looper for infinite loop
        looper = AVPlayerLooper(player: queue, templateItem: item)

        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        self.playerLayer = layer
        self.player = queue
        queue.play()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: .mixWithOthers
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AVAudioSession error: \(error)")
        }
    }

    /// Fallback: if AVPlayerLooper fails, restart video manually
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let player,
              let item = notification.object as? AVPlayerItem,
              player.items().contains(item) || looper == nil else { return }

        // If looper is nil or not working, restart manually
        player.seek(to: .zero)
        player.play()
    }

    private func teardownVideo() {
        cancelFade()
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        looper = nil
        videoURL = nil
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

        // Set intended state IMMEDIATELY so icon updates correctly
        intendedMuted = shouldMute

        if shouldMute {
            // Fading out to mute
            let duration: TimeInterval = animated ? 0.4 : 0
            fadeVolume(to: 0, duration: duration) { [weak self] in
                self?.player?.isMuted = true
                DataManager.shared.updateSettings {
                    $0.backgroundVideoMuted = true
                }
            }
        } else {
            // Unmute and fade in
            let targetVolume = DataManager.shared.settings.backgroundVideoVolume > 0
                ? DataManager.shared.settings.backgroundVideoVolume
                : 1.0
            player.isMuted = false
            player.volume = 0
            let duration: TimeInterval = animated ? 0.4 : 0
            fadeVolume(to: targetVolume, duration: duration) { [weak self] in
                guard let self, let player = self.player else { return }
                DataManager.shared.updateSettings {
                    $0.backgroundVideoMuted = false
                    $0.backgroundVideoVolume = player.volume
                }
            }
        }
    }

    /// Set player volume directly (NO settings save — used during drag to avoid crashes)
    func setPlayerVolume(_ newVolume: Float) {
        guard let player else { return }
        let clamped = max(0, min(1, newVolume))
        player.volume = clamped
        if clamped > 0 {
            player.isMuted = false
        }
        intendedMuted = clamped == 0
    }

    /// Save current volume to settings (call when gesture ends)
    func saveVolumeSettings() {
        guard let player else { return }
        DataManager.shared.updateSettings {
            $0.backgroundVideoVolume = player.volume
            $0.backgroundVideoMuted = player.volume == 0
        }
    }

    /// Set volume with optional smooth fade (saves settings on completion)
    func setVolume(_ newVolume: Float, animated: Bool = true) {
        guard let player else { return }
        let clamped = max(0, min(1, newVolume))
        intendedMuted = clamped == 0

        if animated {
            fadeVolume(to: clamped, duration: 0.3) { [weak self] in
                guard let self, let player = self.player else { return }
                player.volume = clamped
                if clamped > 0 { player.isMuted = false }
                DataManager.shared.updateSettings {
                    $0.backgroundVideoVolume = clamped
                    $0.backgroundVideoMuted = clamped == 0
                }
            }
        } else {
            player.volume = clamped
            if clamped > 0 { player.isMuted = false }
            DataManager.shared.updateSettings {
                $0.backgroundVideoVolume = clamped
                $0.backgroundVideoMuted = clamped == 0
            }
        }
    }

    /// Smoothly animate volume from current to target value
    private func fadeVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        // Cancel any ongoing fade
        cancelFade()

        guard let player else {
            completion?()
            return
        }

        let startMuted = player.isMuted

        // If currently muted, unmute first and start from 0
        if startMuted {
            player.isMuted = false
            player.volume = 0
        }

        let effectiveStart = startMuted ? Float(0) : player.volume

        guard abs(effectiveStart - target) > 0.001 else {
            completion?()
            return
        }

        fadeStartTime = CACurrentMediaTime()
        fadeDuration = duration
        fadeStartVolume = effectiveStart
        fadeTargetVolume = target
        fadeCompletion = completion

        let displayLink = CADisplayLink(target: self, selector: #selector(fadeStep))
        displayLink.add(to: .main, forMode: .common)
        self.fadeDisplayLink = displayLink
    }

    @objc private func fadeStep(_ link: CADisplayLink) {
        guard let player else {
            link.invalidate()
            fadeDisplayLink = nil
            return
        }

        let elapsed = CACurrentMediaTime() - fadeStartTime
        let progress = min(1, Float(elapsed / fadeDuration))

        // Ease-in-out curve
        let eased = progress < 0.5
            ? 2 * progress * progress
            : 1 - pow(-2 * progress + 2, 2) / 2

        let currentVolume = fadeStartVolume + (fadeTargetVolume - fadeStartVolume) * eased
        player.volume = max(0, min(1, currentVolume))

        if progress >= 1 {
            link.invalidate()
            fadeDisplayLink = nil
            player.volume = fadeTargetVolume
            let completion = fadeCompletion
            fadeCompletion = nil
            completion?()
        }
    }

    /// Cancel any ongoing fade animation
    func cancelFade() {
        fadeDisplayLink?.invalidate()
        fadeDisplayLink = nil
        fadeCompletion = nil
    }
}
