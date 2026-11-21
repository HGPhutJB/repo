import UIKit

/// Khung chính: thanh tab (Tìm kiếm / Đang phát) + thanh phát nhỏ + hộp thoại báo lỗi phát nhạc.
final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let mini = MiniPlayerView()
    private let searchNav = UINavigationController(rootViewController: SearchViewController())
    private let nowPlaying = NowPlayingViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = Theme.background

        searchNav.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 0)
        nowPlaying.tabBarItem = UITabBarItem(title: "Đang phát", image: Icons.music(25), tag: 1)
        viewControllers = [searchNav, nowPlaying]
        tabBar.tintColor = Theme.accent

        mini.translatesAutoresizingMaskIntoConstraints = false
        mini.isHidden = true
        mini.onTap = { [weak self] in
            self?.selectedIndex = 1
            self?.updateMini()
        }
        view.addSubview(mini)
        NSLayoutConstraint.activate([
            mini.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mini.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mini.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            mini.heightAnchor.constraint(equalToConstant: MiniPlayerView.height)
        ])

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(stateChanged), name: .playerStateChanged, object: nil)
        center.addObserver(self, selector: #selector(playbackFailed(_:)), name: .playerFailed, object: nil)
    }

    @objc private func stateChanged() {
        updateMini()
    }

    private func updateMini() {
        let hasSong = PlayerEngine.shared.currentSong != nil
        let show = hasSong && selectedIndex == 0
        mini.isHidden = !show
        searchNav.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0,
                                                           bottom: show ? MiniPlayerView.height : 0, right: 0)
        if show { mini.update() }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateMini()
    }

    @objc private func playbackFailed(_ notification: Notification) {
        let message = (notification.userInfo?["message"] as? String) ?? "Lỗi không rõ"
        let alert = UIAlertController(title: "Không phát được", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel, handler: nil))
        var top: UIViewController = self
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(alert, animated: true, completion: nil)
    }
}
