import UIKit
import SnapKit
import AVFoundation

final class MusicPlayerViewController: UIViewController {
    private let backgroundView = PersonalBackgroundView()
    private let overlayView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    private let closeButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    private let tableView = UITableView()
    private let miniPlayer = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))

    private let artworkView = UIImageView()
    private let songTitleLabel = UILabel()
    private let artistLabel = UILabel()
    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupBackground()
        setupOverlay()
        setupHeader()
        setupTable()
        setupMiniPlayer()
        updateUI()

        MusicManager.shared.onPlaybackStateChanged = { [weak self] in self?.updatePlaybackUI() }
        MusicManager.shared.onSongChanged = { [weak self] in self?.updateUI(); self?.tableView.reloadData() }
        MusicManager.shared.onProgressUpdate = { [weak self] cur, dur in self?.updateProgress(cur, dur) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        tableView.reloadData()
        updateUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupOverlay() {
        view.addSubview(overlayView)
        overlayView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupHeader() {
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        closeButton.layer.cornerRadius = 16
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

        titleLabel.text = "Ваш плейлист"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        addButton.layer.cornerRadius = 16
        addButton.clipsToBounds = true
        addButton.addTarget(self, action: #selector(addSong), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [closeButton, titleLabel, addButton])
        header.alignment = .center
        closeButton.snp.makeConstraints { $0.size.equalTo(32) }
        addButton.snp.makeConstraints { $0.size.equalTo(32) }

        overlayView.contentView.addSubview(header)
        header.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    private func setupTable() {
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SongCell.self, forCellReuseIdentifier: SongCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: 60, left: 0, bottom: 220, right: 0)

        overlayView.contentView.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).inset(56)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    private func setupMiniPlayer() {
        miniPlayer.layer.cornerRadius = 20
        miniPlayer.layer.cornerCurve = .continuous
        miniPlayer.clipsToBounds = true

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 8
        artworkView.layer.cornerCurve = .continuous
        artworkView.backgroundColor = UIColor(white: 0.2, alpha: 1)
        artworkView.image = UIImage(systemName: "music.note")
        artworkView.tintColor = .gray

        songTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        songTitleLabel.textColor = .white
        songTitleLabel.lineBreakMode = .byTruncatingTail

        artistLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        artistLabel.textColor = UIColor(white: 0.6, alpha: 1)
        artistLabel.lineBreakMode = .byTruncatingTail

        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.tintColor = .white
        progressSlider.setThumbImage(UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10)), for: .normal)
        progressSlider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)

        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        currentTimeLabel.textColor = UIColor(white: 0.6, alpha: 1)
        currentTimeLabel.text = "0:00"

        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = UIColor(white: 0.6, alpha: 1)
        durationLabel.text = "0:00"
        durationLabel.textAlignment = .right

        let bigConfig = UIImage.SymbolConfiguration(pointSize: 28)
        let smallConfig = UIImage.SymbolConfiguration(pointSize: 22)

        prevButton.setImage(UIImage(systemName: "backward.fill", withConfiguration: smallConfig), for: .normal)
        prevButton.tintColor = .white
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)

        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: bigConfig), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        nextButton.setImage(UIImage(systemName: "forward.fill", withConfiguration: smallConfig), for: .normal)
        nextButton.tintColor = .white
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [prevButton, playPauseButton, nextButton])
        controls.alignment = .center
        controls.spacing = 36

        deleteButton.setTitle("Удалить из профиля", for: .normal)
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.backgroundColor = UIColor(white: 0.2, alpha: 1)
        deleteButton.layer.cornerRadius = 14
        deleteButton.layer.cornerCurve = .continuous
        deleteButton.addTarget(self, action: #selector(deleteSong), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [songTitleLabel, artistLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [artworkView, infoStack])
        topRow.alignment = .center
        topRow.spacing = 12
        artworkView.snp.makeConstraints { $0.size.equalTo(50) }

        let timeRow = UIStackView(arrangedSubviews: [currentTimeLabel, durationLabel])
        timeRow.distribution = .equalSpacing

        let mainStack = UIStackView(arrangedSubviews: [topRow, progressSlider, timeRow, controls, deleteButton])
        mainStack.axis = .vertical
        mainStack.alignment = .center
        mainStack.spacing = 10

        miniPlayer.contentView.addSubview(mainStack)
        mainStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
        }
        progressSlider.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        timeRow.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        deleteButton.snp.makeConstraints { $0.leading.trailing.equalToSuperview().inset(20); $0.height.equalTo(44) }

        overlayView.contentView.addSubview(miniPlayer)
        miniPlayer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
        }
    }

    private func updateUI() {
        let song = MusicManager.shared.currentSong
        songTitleLabel.text = song?.title ?? "Не выбрано"
        artistLabel.text = song?.artist ?? ""

        if let artwork = song?.artwork {
            artworkView.image = artwork
        } else {
            artworkView.image = UIImage(systemName: "music.note")
            artworkView.tintColor = .gray
        }

        updatePlaybackUI()
        updateProgress(MusicManager.shared.currentTime, MusicManager.shared.duration)
    }

    private func updatePlaybackUI() {
        let isPlaying = MusicManager.shared.isPlaying
        let config = UIImage.SymbolConfiguration(pointSize: 28)
        playPauseButton.setImage(
            UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: config),
            for: .normal
        )
    }

    private func updateProgress(_ current: Double, _ total: Double) {
        guard total > 0 else {
            progressSlider.value = 0
            currentTimeLabel.text = "0:00"
            durationLabel.text = "0:00"
            return
        }
        progressSlider.setValue(Float(current / total), animated: true)
        currentTimeLabel.text = formatTime(current)
        durationLabel.text = formatTime(total)
    }

    private func formatTime(_ time: Double) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func addSong() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    @objc private func playPauseTapped() {
        MusicManager.shared.togglePlayPause()
    }

    @objc private func prevTapped() {
        MusicManager.shared.playPrevious()
    }

    @objc private func nextTapped() {
        MusicManager.shared.playNext()
    }

    @objc private func sliderChanged(_ slider: UISlider) {
        let dur = MusicManager.shared.duration
        guard dur > 0 else { return }
        MusicManager.shared.seek(to: Double(slider.value) * dur)
    }

    @objc private func deleteSong() {
        let idx = MusicManager.shared.currentSongIndex
        guard idx >= 0 else { return }
        MusicManager.shared.removeSong(at: idx)
        tableView.reloadData()
        updateUI()
    }
}

extension MusicPlayerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        MusicManager.shared.songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseID, for: indexPath) as! SongCell
        let song = MusicManager.shared.songs[indexPath.row]
        let isCurrent = indexPath.row == MusicManager.shared.currentSongIndex
        cell.configure(with: song, isPlaying: isCurrent && MusicManager.shared.isPlaying, isCurrent: isCurrent)
        cell.onPlayTap = { [weak self] in
            MusicManager.shared.play(at: indexPath.row)
            self?.tableView.reloadData()
            self?.updateUI()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        60
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MusicManager.shared.play(at: indexPath.row)
        tableView.reloadData()
        updateUI()
    }
}

extension MusicPlayerViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let title = url.deletingPathExtension().lastPathComponent
            MusicManager.shared.addSong(from: url, title: title, artist: "Неизвестен")
        }
        tableView.reloadData()
        updateUI()
    }
}

// MARK: - SongCell
private final class SongCell: UITableViewCell {
    static let reuseID = "SongCell"
    var onPlayTap: (() -> Void)?

    private let playButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let menuButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        playButton.backgroundColor = UIColor.systemBlue
        playButton.layer.cornerRadius = 18
        playButton.clipsToBounds = true
        playButton.tintColor = .white
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.snp.makeConstraints { $0.size.equalTo(36) }

        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.6, alpha: 1)
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        menuButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        menuButton.tintColor = UIColor(white: 0.5, alpha: 1)

        let stack = UIStackView(arrangedSubviews: [playButton, textStack, menuButton])
        stack.alignment = .center
        stack.spacing = 12
        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.top.bottom.equalToSuperview().inset(8)
        }
        textStack.snp.makeConstraints { $0.leading.equalTo(playButton.snp.trailing).offset(12) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with song: SongItem, isPlaying: Bool, isCurrent: Bool) {
        titleLabel.text = song.title
        let durationStr = song.duration > 0 ? formatDuration(song.duration) : ""
        let sizeStr = formatFileSize(song.fileURL)
        let parts = [durationStr, song.artist, sizeStr].filter { !$0.isEmpty }
        subtitleLabel.text = parts.joined(separator: " • ")

        let imageName = isCurrent ? (isPlaying ? "pause.fill" : "play.fill") : "play.fill"
        playButton.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)), for: .normal)
    }

    @objc private func playTapped() { onPlayTap?() }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatFileSize(_ url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size < 1024 * 1024 {
            return "\(size / 1024) КБ"
        }
        return "\(size / (1024 * 1024)) МБ"
    }
}
