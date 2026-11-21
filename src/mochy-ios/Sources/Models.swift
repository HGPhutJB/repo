import Foundation

/// Một bài hát trong kết quả tìm kiếm / hàng đợi.
struct Song {
    let videoId: String
    let title: String
    let artist: String
    let subtitle: String      // "Nghệ sĩ · Album · 3:45"
    let duration: String?     // "3:45" nếu có
    let thumbnailURL: URL?
}

/// Lỗi có thông điệp tiếng Việt để hiện thẳng lên màn hình (giúp tìm lỗi trên máy thật).
enum MochyError: Error, LocalizedError {
    case http(Int, String, String)
    case badResponse(String)
    case noStream(String)
    case playback(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let host, let snippet):
            return "Máy chủ \(host) trả về HTTP \(code)\n\(snippet)"
        case .badResponse(let s):
            return "Phản hồi không hợp lệ: \(s)"
        case .noStream(let s):
            return s
        case .playback(let s):
            return s
        }
    }
}

/// Luồng âm thanh đã giải ra được từ YouTube Music.
struct StreamInfo {
    let url: URL
    let userAgent: String
    let mimeType: String
    let clientName: String
}
