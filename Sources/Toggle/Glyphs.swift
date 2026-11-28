import SwiftUI

struct BluetoothShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [CGPoint] = [
            .init(x: 6.5, y: 6.5), .init(x: 17.5, y: 17.5), .init(x: 12, y: 23),
            .init(x: 12, y: 1), .init(x: 17.5, y: 6.5), .init(x: 6.5, y: 17.5),
        ]
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - 24 * scale) / 2
        let dy = rect.minY + (rect.height - 24 * scale) / 2
        var path = Path()
        for (index, point) in pts.enumerated() {
            let mapped = CGPoint(x: dx + point.x * scale, y: dy + point.y * scale)
            if index == 0 { path.move(to: mapped) } else { path.addLine(to: mapped) }
        }
        return path
    }
}

struct AirDropArcs: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let centerX = rect.midX
        let centerY = rect.minY + 10 * scale
        var path = Path()
        for radius in [3.5, 6.5, 9.5] as [CGFloat] {
            let length = radius * scale
            var degrees: CGFloat = 128
            var first = true
            while degrees <= 412 {
                let angle = degrees * .pi / 180
                let point = CGPoint(
                    x: centerX + length * CoreGraphics.cos(angle),
                    y: centerY + length * CoreGraphics.sin(angle)
                )
                if first {
                    path.move(to: point)
                    first = false
                } else {
                    path.addLine(to: point)
                }
                degrees += 6
            }
        }
        return path
    }
}

struct AirDropTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let centerX = rect.midX
        let centerY = rect.minY + 10 * scale
        var path = Path()
        path.move(to: CGPoint(x: centerX - 2.4 * scale, y: centerY + 2.8 * scale))
        path.addLine(to: CGPoint(x: centerX + 2.4 * scale, y: centerY + 2.8 * scale))
        path.addLine(to: CGPoint(x: centerX, y: centerY + 8 * scale))
        path.closeSubpath()
        return path
    }
}

enum ToggleSymbol: Equatable {
    case system(String)
    case bluetooth
    case airDrop
}

struct ToggleGlyph: View {
    var symbol: ToggleSymbol
    var size: CGFloat = 14

    var body: some View {
        switch symbol {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        case .bluetooth:
            BluetoothShape()
                .stroke(style: StrokeStyle(lineWidth: max(1.2, size / 10), lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        case .airDrop:
            ZStack {
                AirDropArcs()
                    .stroke(style: StrokeStyle(lineWidth: max(1.1, size / 12), lineCap: .round))
                AirDropTriangle().fill()
            }
            .frame(width: size, height: size)
        }
    }
}

extension ToggleID {
    var activeTint: Color {
        switch self {
        case .nightShift, .trueTone: .orange
        case .keepAwake: .brown
        case .lowPowerMode: .yellow
        case .doNotDisturb: .indigo
        default: .accentColor
        }
    }

    func symbol(isOn: Bool) -> ToggleSymbol {
        switch self {
        case .wifi: .system(isOn ? "wifi" : "wifi.slash")
        case .bluetooth: .bluetooth
        case .airDrop: .airDrop
        case .airPods: .system("airpods")
        case .darkMode: .system(isOn ? "moon.fill" : "sun.max.fill")
        case .nightShift: .system("sun.max.fill")
        case .trueTone: .system("sun.haze.fill")
        case .mute: .system(isOn ? "speaker.slash.fill" : "speaker.wave.2.fill")
        case .keepAwake: .system("cup.and.saucer.fill")
        case .lowPowerMode: .system("leaf.fill")
        case .doNotDisturb: .system("moon.circle.fill")
        case .stageManager: .system("rectangle.stack.fill")
        case .hideDesktopIcons: .system("square.grid.2x2.fill")
        case .hiddenFiles: .system(isOn ? "eye.fill" : "eye.slash")
        case .fileExtensions: .system("doc.badge.ellipsis")
        case .dockAutohide: .system("dock.arrow.down.rectangle")
        }
    }
}
