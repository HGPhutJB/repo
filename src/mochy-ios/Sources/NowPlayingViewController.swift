import UIKit

/// Tab "Đang phát": ảnh bìa lớn, tên bài, thanh tua, nút điều khiển.
final class NowPlayingViewController: UIViewController {
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let slider = UISlider()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var scrubbing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 10
        artworkView.backgroundColor = Theme.placeholder
        view.addSubview(artworkView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = Theme.primaryText
        titleLabel.numberOfLines = 2
        view.addSubview(titleLabel)

        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = UIFont.systemFont(ofSize: 19, weight: .regular)
        artistLabel.textColor = Theme.accent
        view.addSubview(artistLabel)

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = Theme.secondaryText
        slider.thumbTintColor = Theme.secondaryText
        slider.addTarget(self, action: #selector(scrubBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(scrubEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(slider)

        for label in [elapsedLabel, remainingLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = Theme.secondaryText
            view.addSubview(label)
        }
        remainingLabel.textAlignment = .right

        configure(button: previousButton, image: Icons.previous(36), action: #selector(previousTapped))
        configure(button: playButton, image: Icons.play(56), action: #selector(playTapped))
        configure(button: nextButton, image: Icons.next(36), action: #selector(nextTapped))

        let controls = UIStackView(arrangedSubviews: [previousButton, playButton, nextButton])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 48
        view.addSubview(controls)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 12)
        statusLabel.textColor = Theme.secondaryText
        view.addSubview(statusLabel)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            artworkView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            artworkView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 24),
            artworkView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.76),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 26),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            slider.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 22),
            slider.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            elapsedLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            elapsedLabel.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            remainingLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            remainingLabel.trailingAnchor.constraint(equalTo: slider.trailingAnchor),

            controls.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 18),
            controls.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refresh), name: .playerStateChanged, object: nil)
        center.addObserver(self, selector: #selector(timeChanged), name: .playerTimeChanged, object: nil)
        refresh()
    }

    private func configure(button: UIButton, image: UIImage, action: Selector) {
        button.setImage(image, for: .normal)
        button.tintColor = Theme.primaryText
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: - Cập nhật giao diện

    @objc private func refresh() {
        let engine = PlayerEngine.shared
        if let song = engine.currentSong {
            titleLabel.text = song.title
            artistLabel.text = song.artist
        } else {
            titleLabel.text = "Chưa phát bài nào"
            artistLabel.text = "Hãy tìm một bài ở tab Tìm kiếm"
        }
        artworkView.image = engine.artwork
        playButton.setImage(engine.isPlaying ? Icons.pause(56) : Icons.play(56), for: .normal)
        if engine.isLoading {
            statusLabel.text = "Đang tải luồng nhạc…"
        } else {
            statusLabel.text = engine.lastError ?? ""
        }
        timeChanged()
    }

    @objc private func timeChanged() {
        if scrubbing { return }
        let engine = PlayerEngine.shared
        slider.maximumValue = Float(max(engine.duration, 1))
        slider.value = Float(min(engine.currentTime, max(engine.duration, 1)))
        elapsedLabel.text = formatTime(engine.currentTime)
        remainingLabel.text = engine.duration > 0 ? "-" + formatTime(engine.duration - engine.currentTime) : "-:--"
    }

    // MARK: - Hành động

    @objc private func playTapped() { PlayerEngine.shared.togglePlayPause() }
    @objc private func nextTapped() { PlayerEngine.shared.next() }
    @objc private func previousTapped() { PlayerEngine.shared.previous() }

    @objc private func scrubBegan() { scrubbing = true }

    @objc private func scrubChanged() {
        let engine = PlayerEngine.shared
        elapsedLabel.text = formatTime(Double(slider.value))
        remainingLabel.text = engine.duration > 0 ? "-" + formatTime(engine.duration - Double(slider.value)) : "-:--"
    }

    @objc private func scrubEnded() {
        PlayerEngine.shared.seek(to: Double(slider.value))
        scrubbing = false
    }
}
