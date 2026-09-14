import SwiftUI

nonisolated struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }

    mutating func jitter(_ amount: CGFloat) -> CGFloat {
        CGFloat(next() * 2 - 1) * amount
    }
}

nonisolated extension String {
    /// `hashValue` changes per launch, so shapes seeded from it would redraw differently each time.
    var stableSeed: UInt64 {
        unicodeScalars.reduce(1_469_598_103_934_665_603) { ($0 ^ UInt64($1.value)) &* 1_099_511_628_211 }
    }
}

nonisolated struct SketchyRect: Shape {
    var cornerRadius: CGFloat = 18
    var wobble: CGFloat = 1.4
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        let (x0, x1, y0, y1) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        let sides: [(from: CGPoint, to: CGPoint, corner: CGPoint, next: CGPoint)] = [
            (CGPoint(x: x0 + r, y: y0), CGPoint(x: x1 - r, y: y0), CGPoint(x: x1, y: y0), CGPoint(x: x1, y: y0 + r)),
            (CGPoint(x: x1, y: y0 + r), CGPoint(x: x1, y: y1 - r), CGPoint(x: x1, y: y1), CGPoint(x: x1 - r, y: y1)),
            (CGPoint(x: x1 - r, y: y1), CGPoint(x: x0 + r, y: y1), CGPoint(x: x0, y: y1), CGPoint(x: x0, y: y1 - r)),
            (CGPoint(x: x0, y: y1 - r), CGPoint(x: x0, y: y0 + r), CGPoint(x: x0, y: y0), CGPoint(x: x0 + r, y: y0)),
        ]
        var path = Path()
        path.move(to: sides[0].from.nudged(&rng, wobble))
        for side in sides {
            let steps = max(1, Int(side.from.distance(to: side.to) / 40))
            for step in 1...steps {
                let t0 = CGFloat(step - 1) / CGFloat(steps)
                let t1 = CGFloat(step) / CGFloat(steps)
                path.addQuadCurve(
                    to: side.from.lerp(side.to, t1).nudged(&rng, wobble * 0.5),
                    control: side.from.lerp(side.to, (t0 + t1) / 2).nudged(&rng, wobble)
                )
            }
            path.addQuadCurve(to: side.next.nudged(&rng, wobble * 0.5), control: side.corner.nudged(&rng, wobble))
        }
        let start = sides[0].from
        path.addLine(to: CGPoint(x: start.x + min(12, rect.width * 0.1), y: start.y + rng.jitter(wobble)))
        return path
    }
}

nonisolated struct SketchyEllipse: Shape {
    var wobble: CGFloat = 0.035
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let count = 14
        let points = (0..<count).map { i -> CGPoint in
            let angle = Double(i) / Double(count) * 2 * .pi
            let scale = 1 + rng.jitter(wobble)
            return CGPoint(
                x: rect.midX + cos(angle) * rect.width / 2 * scale,
                y: rect.midY + sin(angle) * rect.height / 2 * scale
            )
        }
        var path = Path()
        path.move(to: points[count - 1].lerp(points[0], 0.5))
        for i in 0..<count {
            path.addQuadCurve(to: points[i].lerp(points[(i + 1) % count], 0.5), control: points[i])
        }
        path.closeSubpath()
        return path
    }
}

nonisolated struct Hatch: Shape {
    var spacing: CGFloat = 5
    var seed: UInt64 = 3

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x + rng.jitter(1.5), y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height + rng.jitter(1.5), y: rect.minY))
            x += spacing + rng.jitter(1)
        }
        return path
    }
}

struct CrayonFill<S: Shape>: View {
    var color: Color
    var shape: S
    var seed: UInt64 = 5

    var body: some View {
        ZStack {
            shape.fill(color.opacity(0.5))
            Hatch(seed: seed)
                .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .clipShape(shape)
        }
    }
}

struct SketchyBackground: View {
    var fill: Color = Palette.card
    var seed: UInt64 = 1
    var cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            SketchyRect(cornerRadius: cornerRadius, seed: seed).fill(fill)
            SketchyRect(cornerRadius: cornerRadius, seed: seed)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            SketchyRect(cornerRadius: cornerRadius, wobble: 2.4, seed: seed &+ 11)
                .stroke(Palette.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}

struct PaperBackground: View {
    var body: some View {
        Palette.paper
            .overlay { Image(.paperGrain).resizable(resizingMode: .tile) }
            .ignoresSafeArea()
    }
}

extension View {
    func sketchyCard(fill: Color = Palette.card, seed: UInt64 = 1, padding: CGFloat = 16) -> some View {
        self.padding(padding).background { SketchyBackground(fill: fill, seed: seed) }
    }
}

nonisolated extension CGPoint {
    fileprivate func lerp(_ other: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }

    fileprivate func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    fileprivate func nudged(_ rng: inout SeededRandom, _ amount: CGFloat) -> CGPoint {
        CGPoint(x: x + rng.jitter(amount), y: y + rng.jitter(amount))
    }
}
