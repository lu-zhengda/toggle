import SwiftUI

struct BluetoothShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [CGPoint] = [.init(x: 6.5, y: 6.5), .init(x: 17.5, y: 17.5), .init(x: 12, y: 23),
                              .init(x: 12, y: 1), .init(x: 17.5, y: 6.5), .init(x: 6.5, y: 17.5)]
        let s = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - 24 * s) / 2, dy = rect.minY + (rect.height - 24 * s) / 2
        var p = Path()
        for (i, q) in pts.enumerated() {
            let r = CGPoint(x: dx + q.x * s, y: dy + q.y * s)
            if i == 0 { p.move(to: r) } else { p.addLine(to: r) }
        }
        return p
    }
}
struct AirDropArcs: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24, cx = rect.midX, cy = rect.minY + 10 * s
        var p = Path()
        for r in [3.5, 6.5, 9.5] as [CGFloat] {
            var d: CGFloat = 128; var first = true
            while d <= 412 {
                let a = d * .pi / 180
                let q = CGPoint(x: cx + r * s * cos(a), y: cy + r * s * sin(a))
                if first { p.move(to: q); first = false } else { p.addLine(to: q) }
                d += 6
            }
        }
        return p
    }
}
struct AirDropTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24, cx = rect.midX, cy = rect.minY + 10 * s
        var p = Path()
        p.move(to: CGPoint(x: cx - 2.4 * s, y: cy + 2.8 * s))
        p.addLine(to: CGPoint(x: cx + 2.4 * s, y: cy + 2.8 * s))
        p.addLine(to: CGPoint(x: cx, y: cy + 8 * s)); p.closeSubpath()
        return p
    }
}
enum Glyph { case symbol(String), bluetooth, airdrop }

struct GlyphView: View {
    let glyph: Glyph
    var size: CGFloat = 17
    var body: some View {
        switch glyph {
        case .symbol(let n): Image(systemName: n).font(.system(size: size, weight: .medium))
        case .bluetooth:
            BluetoothShape().stroke(style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                .frame(width: size + 1, height: size + 1)
        case .airdrop:
            ZStack { AirDropArcs().stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round)); AirDropTriangle() }
                .frame(width: size + 2, height: size + 2)
        }
    }
}
