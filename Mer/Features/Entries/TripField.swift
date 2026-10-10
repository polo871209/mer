import SwiftUI

struct TripField: View {
    let trips: [Trip]
    @Binding var selection: Trip?
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "suitcase.rolling")
                if let selection {
                    Text(selection.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 140)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                SketchyBackground(fill: selection == nil ? Palette.card : Crayon.sky.color.opacity(0.35), seed: 49, cornerRadius: 10)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Trip")
        .accessibilityValue(selection?.name ?? String(localized: "None"))
        .sheet(isPresented: $isPicking) {
            TripPicker(trips: trips, selection: $selection)
        }
    }
}

private struct TripPicker: View {
    let trips: [Trip]
    @Binding var selection: Trip?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                row(nil)
            } footer: {
                Text("Trip entries stay out of the budget.")
            }
            ForEach(TripStatus.allCases, id: \.self) { status in
                let matches = trips.filter { $0.status() == status }
                if !matches.isEmpty {
                    Section {
                        ForEach(matches) { row($0) }
                    } header: {
                        Text(status.title)
                    }
                }
            }
        }
        .pickerSheet(Text("Trip"))
    }

    private func row(_ trip: Trip?) -> some View {
        let isSelected = selection == trip
        return Button {
            selection = trip
            Haptics.picked()
            dismiss()
        } label: {
            HStack {
                Text(trip?.name ?? String(localized: "None"))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold)
                }
            }
            .foregroundStyle(Palette.ink)
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
