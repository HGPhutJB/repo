import UIKit

/// Một dòng bài hát: ảnh bìa vuông bo góc + tên + nghệ sĩ (giống danh sách Apple Music).
final class SongCell: UITableViewCell {
    static let reuseId = "SongCell"

    private let thumb = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var representedURL: URL?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        backgroundColor = Theme.background

        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 6
        thumb.backgroundColor = Theme.placeholder
        contentView.addSubview(thumb)

        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = Theme.primaryText
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = Theme.secondaryText

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumb.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 48),
            thumb.heightAnchor.constraint(equalToConstant: 48),
            stack.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedURL = nil
        thumb.image = nil
    }

    func configure(song: Song, isCurrent: Bool) {
        titleLabel.text = song.title
        titleLabel.textColor = isCurrent ? Theme.accent : Theme.primaryText
        subtitleLabel.text = song.subtitle.isEmpty ? song.artist : song.subtitle
        representedURL = song.thumbnailURL
        thumb.image = nil
        if let url = song.thumbnailURL {
            ImageLoader.shared.load(url) { [weak self] image in
                guard let self = self, self.representedURL == url else { return }
                self.thumb.image = image
            }
        }
    }
}
