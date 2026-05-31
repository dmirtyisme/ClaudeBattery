import SwiftUI

enum StatusGlyphState {
    case waitingForData
    case connectedSafe
    case connectedMedium
    case connectedCritical
    case stale
    case notInstalled
}

enum MenuBarGaugeTint {
    case safe
    case medium
    case critical
    case monochrome
}

struct MenuBarLabelView: View {
    let presentation: MenuBarPresentation

    var body: some View {
        HStack(spacing: 4) {
            MenuBarCircularGauge(
                progress: presentation.progress,
                tint: presentation.tint,
                animated: presentation.animated
            )
            .frame(width: 14, height: 14)

            Text(presentation.title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 4)
    }
}

struct MenuBarCircularGauge: View {
    let progress: Double
    let tint: MenuBarGaugeTint
    let animated: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.22), lineWidth: 2)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? .easeInOut(duration: 0.45) : nil, value: clampedProgress)
        }
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var color: Color {
        switch tint {
        case .safe:       return .green
        case .medium:     return .orange
        case .critical:   return .red
        case .monochrome: return .accentColor
        }
    }
}

/// Compact animated status artwork used anywhere the interface needs a state glyph.
struct StatusGlyphView: View {
    let state: StatusGlyphState
    var size: CGFloat = 28

    @State private var isRotating = false
    @State private var isPulsing = false

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .onAppear {
                isRotating = true
                isPulsing = true
            }
    }

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .waitingForData:
            StarburstShape()
                .stroke(.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .padding(size * 0.12)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .scaleEffect(isPulsing ? 1 : 0.78)
                .opacity(isPulsing ? 1 : 0.55)
                .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: isRotating)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)

        case .connectedSafe:
            progressRing(color: .green, pulsing: false)

        case .connectedMedium:
            progressRing(color: .yellow, pulsing: true)

        case .connectedCritical:
            progressRing(color: .red, pulsing: true)

        case .stale:
            Circle()
                .stroke(.gray, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [size * 0.14, size * 0.12]))
                .padding(lineWidth)

        case .notInstalled:
            SetupGlyphShape()
                .stroke(.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .padding(size * 0.12)
        }
    }

    private var lineWidth: CGFloat {
        max(1.4, size * 0.1)
    }

    private func progressRing(color: Color, pulsing: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth)
        .scaleEffect(pulsing && isPulsing ? 1 : pulsing ? 0.84 : 1)
        .opacity(pulsing && !isPulsing ? 0.62 : 1)
        .animation(
            pulsing ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : nil,
            value: isPulsing
        )
    }
}

private struct StarburstShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let innerRadius = min(rect.width, rect.height) * 0.2
        let outerRadius = min(rect.width, rect.height) * 0.48

        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            path.move(to: point(center: center, radius: innerRadius, angle: angle))
            path.addLine(to: point(center: center, radius: outerRadius, angle: angle))
        }
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private struct SetupGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = min(rect.width, rect.height) * 0.2
        let body = rect.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let tickRadius = min(rect.width, rect.height) * 0.48
        let innerTickRadius = tickRadius * 0.78

        path.addEllipse(in: body)
        path.addEllipse(in: body.insetBy(dx: body.width * 0.32, dy: body.height * 0.32))

        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            path.move(to: point(center: center, radius: innerTickRadius, angle: angle))
            path.addLine(to: point(center: center, radius: tickRadius, angle: angle))
        }
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
