// Mochy iOS — trình nghe nhạc cho iOS 12 trở lên (jailbreak rootful hoặc sideload).
//
// Nguồn gốc: đây là bản viết lại bằng Swift/UIKit, dựa trên ý tưởng, luồng gọi YouTube Music và
// bộ thông số client của Mochy Music (https://github.com/realidkroo/mochy-music, GPL-3.0) do realidkroo làm.
// Mochy Music lại phát triển từ ViviMusic và Metrolist. Dự án này giữ nguyên giấy phép GPL-3.0
// và tri ân các tác giả đó; xem thêm NOTICE ở thư mục gốc.

import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = PlayerEngine.shared
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
