import AppKit

// 240° progress arc, gap centred at the bottom (6 o'clock).
// Fills clockwise from 7 o'clock (210°) → 12 → 3 → 5 o'clock (330°).
enum ArcStatusImage {

    static func make(percent: Double, status: UsageStatus, size: CGFloat = 16) -> NSImage {
        let pct = max(0.0, min(1.0, percent))
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let geo = Geo(rect: rect, size: size)
            drawTrack(geo: geo, color: .tertiaryLabelColor)
            if pct > 0.005 { drawFill(geo: geo, percent: pct, color: fillColor(for: status)) }
            return true
        }
        img.isTemplate = false
        return img
    }

    static func makeIdle(size: CGFloat = 16) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawTrack(geo: Geo(rect: rect, size: size), color: .quaternaryLabelColor)
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawTrack(geo: Geo, color: NSColor) {
        color.setStroke()
        let p = basePath(geo: geo)
        p.appendArc(withCenter: geo.center, radius: geo.radius,
                 startAngle: 210, endAngle: -30, clockwise: true)
        p.stroke()
    }

    private static func drawFill(geo: Geo, percent: Double, color: NSColor) {
        let endAngle = 210.0 - 240.0 * percent
        color.setStroke()
        let p = basePath(geo: geo)
        p.appendArc(withCenter: geo.center, radius: geo.radius,
                 startAngle: 210, endAngle: endAngle, clockwise: true)
        p.stroke()
    }

    private static func basePath(geo: Geo) -> NSBezierPath {
        let p = NSBezierPath()
        p.lineWidth = geo.lineWidth
        p.lineCapStyle = .round
        return p
    }

    private static func fillColor(for status: UsageStatus) -> NSColor {
        switch status {
        case .safe:                return .labelColor
        case .medium:              return .systemOrange
        case .critical, .depleted: return .systemRed
        }
    }

    private struct Geo {
        let center: CGPoint; let radius: CGFloat; let lineWidth: CGFloat
        init(rect: CGRect, size: CGFloat) {
            center    = CGPoint(x: rect.midX, y: rect.midY)
            radius    = size * (5.5 / 16)
            lineWidth = max(1.0, size * (1.5 / 16))
        }
    }
}
