import SwiftUI

struct MerEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                MerAvatar(size: 110)
                Text(title).font(.crayon(22, relativeTo: .title2))
            }
        } description: {
            Text(message)
        }
        .foregroundStyle(Palette.ink)
    }
}
