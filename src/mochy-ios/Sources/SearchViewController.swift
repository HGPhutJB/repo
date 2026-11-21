import UIKit

/// Tab "Tìm kiếm": ô tìm + danh sách bài hát. Chạm vào một bài để phát.
final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)
    private var songs: [Song] = []
    private var searchToken = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tìm kiếm"
        view.backgroundColor = Theme.background
        navigationController?.navigationBar.prefersLargeTitles = true

        searchBar.placeholder = "Bài hát, nghệ sĩ"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.returnKeyType = .search
        searchBar.tintColor = Theme.accent
        searchBar.delegate = self
        searchBar.frame = CGRect(x: 0, y: 0, width: 320, height: 56)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SongCell.self, forCellReuseIdentifier: SongCell.reuseId)
        tableView.rowHeight = 64
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 0)
        tableView.keyboardDismissMode = .onDrag
        tableView.tableHeaderView = searchBar
        tableView.tableFooterView = makeFooter()
        view.addSubview(tableView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.textColor = Theme.secondaryText
        messageLabel.text = "Nhập tên bài hát hoặc nghệ sĩ rồi bấm Tìm."
        view.addSubview(messageLabel)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(playerChanged),
                                               name: .playerStateChanged, object: nil)
    }

    private func makeFooter() -> UIView {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 320, height: 72))
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = Theme.secondaryText
        label.text = "Mochy iOS · chuyển thể từ Mochy Music của realidkroo\n(github.com/realidkroo/mochy-music, GPL-3.0)"
        return label
    }

    @objc private func playerChanged() {
        tableView.reloadData()
    }

    // MARK: - Tìm kiếm

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        let query = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return }
        searchToken += 1
        let token = searchToken
        spinner.startAnimating()
        messageLabel.isHidden = true

        InnerTube.shared.search(query) { [weak self] result in
            guard let self = self, token == self.searchToken else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let list):
                self.songs = list
                self.tableView.reloadData()
                self.messageLabel.text = "Không tìm thấy kết quả."
                self.messageLabel.isHidden = !list.isEmpty
            case .failure(let error):
                self.songs = []
                self.tableView.reloadData()
                self.messageLabel.text = "Tìm kiếm bị lỗi:\n\(error.localizedDescription)"
                self.messageLabel.isHidden = false
            }
        }
    }

    // MARK: - Bảng

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseId, for: indexPath)
        if let songCell = cell as? SongCell {
            let song = songs[indexPath.row]
            let current = PlayerEngine.shared.currentSong?.videoId == song.videoId
            songCell.configure(song: song, isCurrent: current)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        PlayerEngine.shared.play(queue: songs, index: indexPath.row)
    }
}
