import UIKit

/// Thanh phát nhỏ nằm trên thanh tab (như Apple Music). Chạm vào thanh để mở tab "Đang phát".
final class MiniPlayerView: UIView {
    static let height: CGFloat = 60

    private let thumb = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let line = UIView()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        backgroundColor = Theme.miniBackground

        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = Theme.separator
        addSubview(line)

        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 6
        thumb.backgroundColor = Theme.placeholder
        addSubview(thumb)

        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = Theme.primaryText
        artistLabel.font = UIFont.systemFont(ofSize: 13)
        artistLabel.textColor = Theme.secondaryText
        let texts = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        texts.axis = .vertical
        texts.spacing = 1
        texts.translatesAutoresizingMaskIntoConstraints = false
        addSubview(texts)

        for button in [playButton, nextButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintColor = Theme.primaryText
            addSubview(button)
        }
        nextButton.setImage(Icons.next(26), for: .normal)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5),

            thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 42),
            thumb.heightAnchor.constraint(equalToConstant: 42),

            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 40),
            nextButton.heightAnchor.constraint(equalToConstant: 40),

            playButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -4),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 40),
            playButton.heightAnchor.constraint(equalToConstant: 40),

            texts.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            texts.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -8),
            texts.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        update()
    }

    func update() {
        let engine = PlayerEngine.shared
        titleLabel.text = engine.currentSong?.title ?? ""
        artistLabel.text = engine.isLoading ? "Đang tải…" : (engine.currentSong?.artist ?? "")
        thumb.image = engine.artwork
        playButton.setImage(engine.isPlaying ? Icons.pause(26) : Icons.play(26), for: .normal)
    }

    @objc private func tapped() { onTap?() }
    @objc private func playTapped() { PlayerEngine.shared.togglePlayPause() }
    @objc private func nextTapped() { PlayerEngine.shared.next() }
}
