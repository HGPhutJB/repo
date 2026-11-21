import UIKit

/// Tải ảnh bìa, có cache trong bộ nhớ (giới hạn nhỏ cho iPhone 6).
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 80
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        session.dataTask(with: url) { [weak self] data, _, _ in
            var image: UIImage? = nil
            if let data = data {
                image = UIImage(data: data)
            }
            if let image = image {
                self?.cache.setObject(image, forKey: url as NSURL)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}
