import SwiftUI

nonisolated struct SketchyCurve: Shape {
    var points: [CGPoint]
    var wobble: CGFloat = 0
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let p = points.map { $0.nudged(&rng, wobble) }
        var path = Path()
        guard let first = p.first else { return path }
        path.move(to: first)
        guard p.count > 1 else { return path }
        let tangents = Self.monotoneTangents(p)
        for i in 0..<(p.count - 1) {
            let third = (p[i + 1].x - p[i].x) / 3
            path.addCurve(
                to: p[i + 1],
                control1: CGPoint(x: p[i].x + third, y: p[i].y + tangents[i] * third),
                control2: CGPoint(x: p[i + 1].x - third, y: p[i + 1].y - tangents[i + 1] * third)
            )
        }
        return path
    }

    // Fritsch–Carlson monotone cubic interpolation: https://en.wikipedia.org/wiki/Monotone_cubic_interpolation
    private static func monotoneTangents(_ p: [CGPoint]) -> [CGFloat] {
        let slopes = zip(p, p.dropFirst()).map { a, b in b.x == a.x ? 0 : (b.y - a.y) / (b.x - a.x) }
        var tangents = [slopes[0]]
        for i in 1..<slopes.count {
            tangents.append(slopes[i - 1] * slopes[i] <= 0 ? 0 : (slopes[i - 1] + slopes[i]) / 2)
        }
        tangents.append(slopes[slopes.count - 1])
        for i in slopes.indices {
            guard slopes[i] != 0 else {
                tangents[i] = 0
                tangents[i + 1] = 0
                continue
            }
            let a = tangents[i] / slopes[i]
            let b = tangents[i + 1] / slopes[i]
            let length = a * a + b * b
            if length > 9 {
                let scale = 3 / length.squareRoot()
                tangents[i] = scale * a * slopes[i]
                tangents[i + 1] = scale * b * slopes[i]
            }
        }
        return tangents
    }
}
