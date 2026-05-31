import Foundation
import AVFoundation
import UIKit

struct SongItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var artist: String
    var fileName: String
    var artworkFileName: String
    var duration: Double

    init(id: UUID = UUID(), title: String, artist: String, fileName: String, artworkFileName: String = "", duration: Double = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.artworkFileName = artworkFileName
        self.duration = duration
    }

    var artwork: UIImage? {
        guard !artworkFileName.isEmpty else { return nil }
        let dir = MusicManager.songsDirectory
        let path = dir.appendingPathComponent(artworkFileName).path
        return UIImage(contentsOfFile: path)
    }

    var fileURL: URL {
        MusicManager.songsDirectory.appendingPathComponent(fileName)
    }
}

@MainActor
final class MusicManager {
    static let shared = MusicManager()

    static let songsDirectory: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SteelSongs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let songsKey = "steel.songs.v1"
    private let currentSongKey = "steel.currentSong"

    private(set) var songs: [SongItem] = []
    private(set) var currentSongIndex: Int = -1

    private var player: AVAudioPlayer?
    private var _isPlaying = false
    var isPlaying: Bool { _isPlaying }

    var currentSong: SongItem? {
        guard currentSongIndex >= 0 && currentSongIndex < songs.count else { return nil }
        return songs[currentSongIndex]
    }

    private var updateTimer: Timer?

    var onPlaybackStateChanged: (() -> Void)?
    var onSongChanged: (() -> Void)?
    var onProgressUpdate: ((Double, Double) -> Void)?

    private init() {
        loadSongs()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func loadSongs() {
        guard let data = UserDefaults.standard.data(forKey: songsKey),
              let decoded = try? JSONDecoder().decode([SongItem].self, from: data) else {
            songs = []
            return
        }
        songs = decoded
        currentSongIndex = UserDefaults.standard.integer(forKey: currentSongKey)
        if currentSongIndex >= songs.count { currentSongIndex = -1 }
    }

    private func saveSongs() {
        if let data = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(data, forKey: songsKey)
        }
        UserDefaults.standard.set(currentSongIndex, forKey: currentSongKey)
    }

    func addSong(from url: URL, title: String, artist: String, artworkURL: URL? = nil) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension
        let songFileName = "\(UUID().uuidString).\(ext)"
        let destURL = Self.songsDirectory.appendingPathComponent(songFileName)

        do {
            try FileManager.default.copyItem(at: url, to: destURL)
        } catch {
            do {
                try FileManager.default.moveItem(at: url, to: destURL)
            } catch {
                print("Failed to copy song: \(error)")
                return
            }
        }

        var artworkFileName = ""
        if let artURL = artworkURL {
            let artAccessing = artURL.startAccessingSecurityScopedResource()
            defer { if artAccessing { artURL.stopAccessingSecurityScopedResource() } }
            let artExt = artURL.pathExtension
            let artName = "\(UUID().uuidString).\(artExt)"
            let artDest = Self.songsDirectory.appendingPathComponent(artName)
            try? FileManager.default.copyItem(at: artURL, to: artDest)
            artworkFileName = artName
        }

        let asset = AVURLAsset(url: destURL)
        let duration = CMTimeGetSeconds(asset.duration)

        let song = SongItem(
            title: title.isEmpty ? url.deletingPathExtension().lastPathComponent : title,
            artist: artist.isEmpty ? "Неизвестен" : artist,
            fileName: songFileName,
            artworkFileName: artworkFileName,
            duration: duration
        )

        songs.append(song)
        saveSongs()
        onSongChanged?()
    }

    func removeSong(at index: Int) {
        guard index >= 0 && index < songs.count else { return }
        let song = songs[index]

        if currentSongIndex == index {
            stop()
            currentSongIndex = -1
        } else if currentSongIndex > index {
            currentSongIndex -= 1
        }

        try? FileManager.default.removeItem(at: song.fileURL)
        if !song.artworkFileName.isEmpty {
            try? FileManager.default.removeItem(at: Self.songsDirectory.appendingPathComponent(song.artworkFileName))
        }

        songs.remove(at: index)
        saveSongs()
        onSongChanged?()
    }

    func play(at index: Int) {
        guard index >= 0 && index < songs.count else { return }
        currentSongIndex = index
        let song = songs[index]

        do {
            try setupAudioSession()
            player = try AVAudioPlayer(contentsOf: song.fileURL)
            player?.delegate = nil
            player?.prepareToPlay()
            player?.play()
            _isPlaying = true
            startTimer()
            saveSongs()
            onPlaybackStateChanged?()
            onSongChanged?()
        } catch {
            print("Playback error: \(error)")
        }
    }

    func pause() {
        player?.pause()
        _isPlaying = false
        stopTimer()
        onPlaybackStateChanged?()
    }

    func resume() {
        guard let player = player else {
            if currentSongIndex >= 0 {
                play(at: currentSongIndex)
            }
            return
        }
        do {
            try setupAudioSession()
        } catch {}
        player.play()
        _isPlaying = true
        startTimer()
        onPlaybackStateChanged?()
    }

    func togglePlayPause() {
        if _isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        _isPlaying = false
        stopTimer()
        onPlaybackStateChanged?()
    }

    func playNext() {
        guard !songs.isEmpty else { return }
        let next = (currentSongIndex + 1) % songs.count
        play(at: next)
    }

    func playPrevious() {
        guard !songs.isEmpty else { return }
        let prev = currentSongIndex <= 0 ? songs.count - 1 : currentSongIndex - 1
        play(at: prev)
    }

    var currentTime: Double {
        player?.currentTime ?? 0
    }

    var duration: Double {
        player?.duration ?? currentSong?.duration ?? 0
    }

    func seek(to time: Double) {
        player?.currentTime = time
    }

    private func startTimer() {
        stopTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.onProgressUpdate?(self.currentTime, self.duration)
            }
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
