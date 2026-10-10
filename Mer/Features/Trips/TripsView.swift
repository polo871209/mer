import SwiftData
import SwiftUI

struct TripsView: View {
    @Query(sort: \Trip.start, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var context
    @State private var isAdding = false
    @State private var pendingDeletion: Trip?

    var body: some View {
        List {
            ForEach(TripStatus.allCases, id: \.self) { status in
                let matches = trips.filter { $0.status() == status }
                if !matches.isEmpty {
                    Section {
                        ForEach(matches) { trip in
                            NavigationLink {
                                TripDashboard(trip: trip, showsClaim: true)
                            } label: {
                                TripRow(trip: trip)
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash") { pendingDeletion = trip }
                                    .tint(.red)
                            }
                        }
                    } header: {
                        Text(status.title)
                    }
                }
            }
            Section {
                Button("Add Trip", systemImage: "plus") { isAdding = true }
            } footer: {
                Text("Trip entries stay out of the budget, but still count in account balances.")
            }
        }
        .paperBackground()
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAdding) { TripEditor(trip: nil) }
        .confirmationDialog("Delete this trip?", item: $pendingDeletion) { trip in
            Button("Delete Trip", role: .destructive) {
                context.delete(trip)
                try? context.save()
                Haptics.deleted()
            }
        } message: { _ in
            Text("Its entries stay, and count in the budget again.")
        }
    }
}

private struct TripRow: View {
    let trip: Trip
    @Environment(\.currencyCode) private var code

    var body: some View {
        let summary = PeriodSummary(entries: trip.entries ?? [], convertingTo: code)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name).foregroundStyle(Palette.ink)
                if let dates = trip.datesText {
                    Text(dates)
                        .font(.caption)
                        .foregroundStyle(Palette.pencil)
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: summary.approximatePrefix + summary.expense.money(code))
                .font(.crayon(17, relativeTo: .body))
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { TripsView() }
        .modelContainer(Store.preview)
}
