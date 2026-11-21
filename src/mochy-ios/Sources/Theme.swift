import UIKit

/// Màu sắc và vài tiện ích giao diện (kiểu Apple Music, chỉ dùng API có sẵn từ iOS 12).
enum Theme {
    static let accent = UIColor(red: 250.0 / 255.0, green: 45.0 / 255.0, blue: 72.0 / 255.0, alpha: 1)
    static let background = UIColor.white
    static let primaryText = UIColor.black
    static let secondaryText = UIColor(white: 0.45, alpha: 1)
    static let separator = UIColor(white: 0.0, alpha: 0.12)
    static let placeholder = UIColor(white: 0.92, alpha: 1)
    static let miniBackground = UIColor(white: 0.97, alpha: 1)
}

/// Định dạng giây thành "m:ss".
func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}
