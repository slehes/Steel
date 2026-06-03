import UIKit
import AVFoundation

/// Singleton that owns the shared AVQueuePlayer for background video.
/// The player keeps running across tab switches and modal presentations.
/// PersonalBackgroundView instances just create AVPlayerLayers pointing to this player.
@MainActor
final class BackgroundVideoManager {
    static let shared = BackgroundVideoManager()
    private init() {
        // Resume video when app returns from background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentFileName: String?

    /// The intended mute state — set immediately on toggle for correct icon display
    private(set) var intendedMuted: Bool = true

    // Fade animation state
    private var fadeDisplayLink: CADisplayLink?
    private var fadeStartTime: TimeInterval = 0
    private var fadeDuration: TimeInterval = 0.3
    private var fadeStartVolume: Float = 0
    private var fadeTargetVolume: Float = 0
    private var fadeCompletion: (() -> Void)?

    // Modal state
    private var modalCount = 0
    private var volumeBeforeModal: Float = 0
    private var mutedBeforeModal: Bool = true

    // MARK: - Player Setup

    /// Ensure the shared player is playing the given video file.
    /// If same file is already playing, just ensures it's playing (no restart).
    func setupIfNeeded(fileName: String) {
        // Same video already playing — just ensure it's active
        if currentFileName == fileName, let player {
            player.play()
            return
        }

        // Different video — teardown and create new
        teardown()

        configureAudioSession()

        let url = BackgroundManager.backgroundsDirectory.appendingPathComponent(fileName)
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

        player = queue
        currentFileName = fileName
        queue.play()

        // Fallback for looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    /// Remove the shared player entirely (e.g., background changed to photo/none)
    func teardownIfActive() {
        teardown()
    }

    private func teardown() {
        cancelFade()
        player?.pause()
        player = nil
        looper = nil
        currentFileName = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
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

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let player,
              let item = notification.object as? AVPlayerItem,
              player.items().contains(item) || looper == nil else { return }
        player.seek(to: .zero)
        player.play()
    }

    /// Resume playback when app returns from background
    @objc private func appDidBecomeActive() {
        guard player != nil, currentFileName != nil else { return }
        configureAudioSession()
        player?.play()
    }

    // MARK: - Player Access

    /// Get the shared player (for creating AVPlayerLayer in views)
    var sharedPlayer: AVQueuePlayer? { player }

    /// Whether a video is currently loaded and playing
    var isVideoActive: Bool { player != nil && currentFileName != nil }

    // MARK: - Playback

    func play() { player?.play() }
    func pause() { player?.pause() }

    // MARK: - Sound Control

    var isMuted: Bool { player?.isMuted ?? true }
    var volume: Float { player?.volume ?? 0 }

    func toggleMuted(animated: Bool = true) {
        guard let player else { return }
        let shouldMute = !player.isMuted
        intendedMuted = shouldMute

        if shouldMute {
            let duration: TimeInterval = animated ? 0.4 : 0
            fadeVolume(to: 0, duration: duration) { [weak self] in
                self?.player?.isMuted = true
                DataManager.shared.updateSettings { $0.backgroundVideoMuted = true }
            }
        } else {
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

    /// Set player volume directly (NO settings save — during drag)
    func setPlayerVolume(_ newVolume: Float) {
        guard let player else { return }
        let clamped = max(0, min(1, newVolume))
        player.volume = clamped
        if clamped > 0 { player.isMuted = false }
        intendedMuted = clamped == 0
    }

    /// Save current volume to settings (on gesture end)
    func saveVolumeSettings() {
        guard let player else { return }
        DataManager.shared.updateSettings {
            $0.backgroundVideoVolume = player.volume
            $0.backgroundVideoMuted = player.volume == 0
        }
    }

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

    // MARK: - Modal Sound Management

    /// Call when a modal is about to be presented — mutes background video
    func modalWillPresent() {
        modalCount += 1
        guard modalCount == 1 else { return } // Only act on first modal
        volumeBeforeModal = player?.volume ?? 0
        mutedBeforeModal = player?.isMuted ?? true
        // Mute background when modal opens
        player?.isMuted = true
        player?.volume = 0
    }

    /// Call when a modal is dismissed — restores background video sound
    func modalDidDismiss() {
        modalCount = max(0, modalCount - 1)
        guard modalCount == 0 else { return } // Only restore when all modals closed
        // Restore previous state
        player?.isMuted = mutedBeforeModal
        if !mutedBeforeModal {
            player?.volume = volumeBeforeModal
        }
    }

    // MARK: - Fade Animation

    private func fadeVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        cancelFade()
        guard let player else { completion?(); return }

        let startMuted = player.isMuted
        if startMuted {
            player.isMuted = false
            player.volume = 0
        }

        let effectiveStart = startMuted ? Float(0) : player.volume
        guard abs(effectiveStart - target) > 0.001 else { completion?(); return }

        fadeStartTime = CACurrentMediaTime()
        fadeDuration = duration
        fadeStartVolume = effectiveStart
        fadeTargetVolume = target
        fadeCompletion = completion

        let displayLink = CADisplayLink(target: self, selector: #selector(fadeStep(_:)))
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

    func cancelFade() {
        fadeDisplayLink?.invalidate()
        fadeDisplayLink = nil
        fadeCompletion = nil
    }
}
