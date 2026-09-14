import SwiftUI

struct CategoryBadge: View {
    var symbol: String
    var crayon: Crayon
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background {
                CrayonFill(color: crayon.color, shape: SketchyEllipse(seed: symbol.stableSeed), seed: symbol.stableSeed)
                SketchyEllipse(seed: symbol.stableSeed).stroke(Palette.ink, lineWidth: 1.6)
            }
            .accessibilityHidden(true)
    }
}
