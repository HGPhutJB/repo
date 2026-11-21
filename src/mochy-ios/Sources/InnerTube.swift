import Foundation

/// Một "client" giả danh app YouTube để xin link phát nhạc trực tiếp.
/// Thông số lấy từ providers/innertube của Mochy Music (GPL-3.0) và được viết lại bằng Swift.
struct PlayerClient {
    let name: String
    let clientId: String
    let version: String
    let userAgent: String
    let origin: String
    let osName: String?
    let osVersion: String?
    let deviceMake: String?
    let deviceModel: String?
    let androidSdkVersion: String?

    var contextClient: [String: Any] {
        var c: [String: Any] = [
            "clientName": name,
            "clientVersion": version,
            "hl": "en",
            "gl": "US"
        ]
        if let v = osName { c["osName"] = v }
        if let v = osVersion { c["osVersion"] = v }
        if let v = deviceMake { c["deviceMake"] = v }
        if let v = deviceModel { c["deviceModel"] = v }
        if let v = androidSdkVersion { c["androidSdkVersion"] = v }
        return c
    }

    static let androidVR161 = PlayerClient(
        name: "ANDROID_VR", clientId: "28", version: "1.61.48",
        userAgent: "com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)",
        origin: "https://music.youtube.com",
        osName: "Android", osVersion: "12", deviceMake: "Oculus", deviceModel: "Quest 3", androidSdkVersion: "32")

    static let androidVR143 = PlayerClient(
        name: "ANDROID_VR", clientId: "28", version: "1.43.32",
        userAgent: "com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)",
        origin: "https://music.youtube.com",
        osName: "Android", osVersion: "12", deviceMake: "Oculus", deviceModel: "Quest 3", androidSdkVersion: "32")

    static let ios = PlayerClient(
        name: "IOS", clientId: "5", version: "21.03.1",
        userAgent: "com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)",
        origin: "https://music.youtube.com",
        osName: "iPhone", osVersion: "18.2.22C152", deviceMake: "Apple", deviceModel: "iPhone16,2", androidSdkVersion: nil)
}

/// Gọi API nội bộ của YouTube Music: tìm bài hát và lấy link âm thanh.
final class InnerTube {
    static let shared = InnerTube()

    private let apiBase = "https://music.youtube.com/youtubei/v1/"
    private let webUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0"
    private let webRemixVersion = "1.20260707.12.00"
    private let songFilter = "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    // MARK: - HTTP

    private func postJSON(_ urlString: String,
                          headers: [String: String],
                          body: [String: Any],
                          completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(MochyError.badResponse("URL sai")))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                completion(.failure(MochyError.badResponse("không có dữ liệu")))
                return
            }
            if code < 200 || code >= 300 {
                let snippet = String(data: data.prefix(160), encoding: .utf8) ?? ""
                completion(.failure(MochyError.http(code, url.host ?? "", snippet)))
                return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = object as? [String: Any] {
                    completion(.success(dict))
                } else {
                    completion(.failure(MochyError.badResponse("không phải JSON object")))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Tìm kiếm

    func search(_ query: String, completion: @escaping (Result<[Song], Error>) -> Void) {
        let client: [String: Any] = [
            "clientName": "WEB_REMIX",
            "clientVersion": webRemixVersion,
            "hl": "vi",
            "gl": "VN"
        ]
        let body: [String: Any] = [
            "context": ["client": client],
            "query": query,
            "params": songFilter
        ]
        let headers: [String: String] = [
            "X-Goog-Api-Format-Version": "1",
            "X-YouTube-Client-Name": "67",
            "X-YouTube-Client-Version": webRemixVersion,
            "X-Origin": "https://music.youtube.com",
            "Referer": "https://music.youtube.com/",
            "User-Agent": webUserAgent
        ]
        postJSON(apiBase + "search?prettyPrint=false", headers: headers, body: body) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let json):
                    completion(.success(InnerTube.parseSongs(json)))
                }
            }
        }
    }

    // MARK: - Lấy link phát

    func resolveStream(videoId: String, completion: @escaping (Result<StreamInfo, Error>) -> Void) {
        let clients: [PlayerClient] = [PlayerClient.androidVR161, PlayerClient.androidVR143, PlayerClient.ios]
        attempt(videoId: videoId, clients: clients, index: 0, notes: [], completion: completion)
    }

    private func attempt(videoId: String,
                         clients: [PlayerClient],
                         index: Int,
                         notes: [String],
                         completion: @escaping (Result<StreamInfo, Error>) -> Void) {
        if index >= clients.count {
            let message = "Không lấy được link nhạc:\n" + notes.joined(separator: "\n")
            DispatchQueue.main.async { completion(.failure(MochyError.noStream(message))) }
            return
        }
        let client = clients[index]
        let body: [String: Any] = [
            "context": ["client": client.contextClient],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        let headers: [String: String] = [
            "X-Goog-Api-Format-Version": "1",
            "X-YouTube-Client-Name": client.clientId,
            "X-YouTube-Client-Version": client.version,
            "User-Agent": client.userAgent
        ]
        let url = client.origin + "/youtubei/v1/player?prettyPrint=false"
        postJSON(url, headers: headers, body: body) { result in
            var next = notes
            switch result {
            case .failure(let error):
                next.append("• \(client.name): \(error.localizedDescription)")
            case .success(let json):
                if let info = InnerTube.pickStream(json, client: client) {
                    DispatchQueue.main.async { completion(.success(info)) }
                    return
                }
                next.append("• \(client.name): \(InnerTube.describePlayability(json))")
            }
            self.attempt(videoId: videoId, clients: clients, index: index + 1, notes: next, completion: completion)
        }
    }

    // MARK: - Phân tích JSON

    /// Đi theo đường dẫn khoá/chỉ số trong JSON, an toàn với dữ liệu thiếu.
    static func dig(_ root: Any?, _ path: [Any]) -> Any? {
        var current = root
        for step in path {
            if let key = step as? String {
                current = (current as? [String: Any])?[key]
            } else if let idx = step as? Int {
                if let array = current as? [Any], idx >= 0, idx < array.count {
                    current = array[idx]
                } else {
                    return nil
                }
            }
        }
        return current
    }

    private static func collectItems(_ node: Any, into out: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            if let item = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                out.append(item)
                return
            }
            for (_, value) in dict {
                collectItems(value, into: &out)
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectItems(value, into: &out)
            }
        }
    }

    private static func findString(_ node: Any, key: String) -> String? {
        if let dict = node as? [String: Any] {
            if let s = dict[key] as? String { return s }
            for (_, value) in dict {
                if let found = findString(value, key: key) { return found }
            }
        } else if let array = node as? [Any] {
            for value in array {
                if let found = findString(value, key: key) { return found }
            }
        }
        return nil
    }

    private static func runs(_ item: [String: Any], column: Int) -> [String] {
        let path: [Any] = ["flexColumns", column, "musicResponsiveListItemFlexColumnRenderer", "text", "runs"]
        guard let list = dig(item, path) as? [[String: Any]] else { return [] }
        return list.compactMap { $0["text"] as? String }
    }

    static func parseSongs(_ json: [String: Any]) -> [Song] {
        var items: [[String: Any]] = []
        collectItems(json, into: &items)
        var songs: [Song] = []
        var seen = Set<String>()
        for item in items {
            guard let videoId = findString(item, key: "videoId"), !seen.contains(videoId) else { continue }
            let title = runs(item, column: 0).joined()
            if title.isEmpty { continue }
            var parts = runs(item, column: 1).filter { $0.trimmingCharacters(in: .whitespaces) != "•" }
            if let first = parts.first, first == "Song" || first == "Video" || first == "Bài hát" {
                parts.removeFirst()
            }
            let artist = parts.first ?? ""
            let duration: String? = (parts.last != nil && parts.last!.contains(":")) ? parts.last : nil
            let subtitle = parts.joined(separator: " · ")

            var thumbURL: URL? = nil
            let thumbPath: [Any] = ["thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails"]
            if let thumbs = dig(item, thumbPath) as? [[String: Any]],
               let raw = thumbs.last?["url"] as? String {
                let sized = raw.replacingOccurrences(of: "=w\\d+-h\\d+", with: "=w226-h226", options: .regularExpression)
                thumbURL = URL(string: sized)
            }
            seen.insert(videoId)
            songs.append(Song(videoId: videoId, title: title, artist: artist,
                              subtitle: subtitle, duration: duration, thumbnailURL: thumbURL))
        }
        return songs
    }

    static func pickStream(_ json: [String: Any], client: PlayerClient) -> StreamInfo? {
        guard let streaming = json["streamingData"] as? [String: Any] else { return nil }
        var all: [[String: Any]] = []
        if let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] { all.append(contentsOf: adaptive) }
        if let muxed = streaming["formats"] as? [[String: Any]] { all.append(contentsOf: muxed) }

        // 1) Âm thanh AAC (audio/mp4) có link trực tiếp: AVPlayer trên iOS 12 phát được.
        let audio = all.filter { format in
            guard let mime = format["mimeType"] as? String else { return false }
            return mime.hasPrefix("audio/mp4") && (format["url"] as? String) != nil
        }
        if let best = audio.max(by: { (a, b) in
            ((a["bitrate"] as? Int) ?? 0) < ((b["bitrate"] as? Int) ?? 0)
        }), let urlString = best["url"] as? String, let url = URL(string: urlString) {
            return StreamInfo(url: url, userAgent: client.userAgent,
                              mimeType: (best["mimeType"] as? String) ?? "audio/mp4", clientName: client.name)
        }

        // 2) Dự phòng: luồng ghép hình + tiếng (itag 18) nếu không có âm thanh riêng.
        let muxedOnly = all.filter { format in
            guard let mime = format["mimeType"] as? String else { return false }
            return mime.hasPrefix("video/mp4") && (format["url"] as? String) != nil && format["audioQuality"] != nil
        }
        if let low = muxedOnly.min(by: { (a, b) in
            ((a["bitrate"] as? Int) ?? 0) < ((b["bitrate"] as? Int) ?? 0)
        }), let urlString = low["url"] as? String, let url = URL(string: urlString) {
            return StreamInfo(url: url, userAgent: client.userAgent,
                              mimeType: (low["mimeType"] as? String) ?? "video/mp4", clientName: client.name)
        }
        return nil
    }

    static func describePlayability(_ json: [String: Any]) -> String {
        let status = (dig(json, ["playabilityStatus", "status"]) as? String) ?? "?"
        let reason = (dig(json, ["playabilityStatus", "reason"]) as? String) ?? ""
        if json["streamingData"] == nil {
            return reason.isEmpty ? "trạng thái \(status), không có luồng" : "\(status): \(reason)"
        }
        return "có luồng nhưng không có link trực tiếp (cần giải mã chữ ký)"
    }
}
