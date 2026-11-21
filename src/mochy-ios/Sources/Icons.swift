import UIKit

/// Icon vẽ bằng code (iOS 12 không có SF Symbols). Trả về ảnh "template" để tô màu bằng tintColor.
enum Icons {
    private static func make(_ size: CGFloat, _ draw: @escaping (CGFloat) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            UIColor.black.setFill()
            draw(size)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func triangle(_ s: CGFloat, x0: CGFloat, x1: CGFloat) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: s * x0, y: s * 0.14))
        p.addLine(to: CGPoint(x: s * x1, y: s * 0.5))
        p.addLine(to: CGPoint(x: s * x0, y: s * 0.86))
        p.close()
        p.fill()
    }

    private static func backTriangle(_ s: CGFloat, x0: CGFloat, x1: CGFloat) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: s * x1, y: s * 0.14))
        p.addLine(to: CGPoint(x: s * x0, y: s * 0.5))
        p.addLine(to: CGPoint(x: s * x1, y: s * 0.86))
        p.close()
        p.fill()
    }

    static func play(_ size: CGFloat) -> UIImage {
        return make(size) { s in Icons.triangle(s, x0: 0.22, x1: 0.9) }
    }

    static func pause(_ size: CGFloat) -> UIImage {
        return make(size) { s in
            UIBezierPath(roundedRect: CGRect(x: s * 0.2, y: s * 0.14, width: s * 0.22, height: s * 0.72), cornerRadius: s * 0.04).fill()
            UIBezierPath(roundedRect: CGRect(x: s * 0.58, y: s * 0.14, width: s * 0.22, height: s * 0.72), cornerRadius: s * 0.04).fill()
        }
    }

    static func next(_ size: CGFloat) -> UIImage {
        return make(size) { s in
            Icons.triangle(s, x0: 0.08, x1: 0.56)
            Icons.triangle(s, x0: 0.44, x1: 0.92)
        }
    }

    static func previous(_ size: CGFloat) -> UIImage {
        return make(size) { s in
            Icons.backTriangle(s, x0: 0.08, x1: 0.56)
            Icons.backTriangle(s, x0: 0.44, x1: 0.92)
        }
    }

    static func music(_ size: CGFloat) -> UIImage {
        return make(size) { s in
            UIBezierPath(ovalIn: CGRect(x: s * 0.14, y: s * 0.60, width: s * 0.30, height: s * 0.26)).fill()
            UIBezierPath(rect: CGRect(x: s * 0.40, y: s * 0.16, width: s * 0.07, height: s * 0.60)).fill()
            let flag = UIBezierPath()
            flag.move(to: CGPoint(x: s * 0.40, y: s * 0.16))
            flag.addLine(to: CGPoint(x: s * 0.86, y: s * 0.08))
            flag.addLine(to: CGPoint(x: s * 0.86, y: s * 0.26))
            flag.addLine(to: CGPoint(x: s * 0.40, y: s * 0.36))
            flag.close()
            flag.fill()
        }
    }
}
