import SwiftUI

struct MerAvatar: View {
    var size: CGFloat = 72
    @Environment(\.currentTripID) private var currentTripID

    var body: some View {
        Image(currentTripID == nil ? .merFace : .merTravelFace)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(SketchyEllipse(seed: 4))
            .overlay { SketchyEllipse(seed: 4).stroke(Palette.ink, lineWidth: 2.2) }
            .accessibilityLabel("Mer the cat")
    }
}
