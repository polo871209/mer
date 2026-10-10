import SwiftData
import SwiftUI

struct TripTitle: View {
    let trip: Trip
    @State private var isConfirmingEnd = false

    var body: some View {
        if trip.status() == .active {
            Button {
                isConfirmingEnd = true
            } label: {
                label.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Asks to end the trip")
            .confirmationDialog("End this trip?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
                Button("End Trip") {
                    trip.end = .now
                    try? trip.modelContext?.save()
                    Haptics.saved()
                }
            } message: {
                Text("Home and Report go back to your budget.")
            }
        } else {
            label
        }
    }

    private var label: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "suitcase.rolling")
                    .font(.system(size: 18, weight: .semibold))
                Text(trip.name)
                    .font(.crayon(20, relativeTo: .title3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(trip.statusText)
                .font(.crayon(14, relativeTo: .subheadline, bold: false))
                .foregroundStyle(Palette.pencil)
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
