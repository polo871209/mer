import SwiftUI

struct MerAvatar: View {
    var size: CGFloat = 72

    var body: some View {
        Image(.merFace)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(SketchyEllipse(seed: 4))
            .overlay { SketchyEllipse(seed: 4).stroke(Palette.ink, lineWidth: 2.2) }
            .accessibilityLabel("Mer the cat")
    }
}
