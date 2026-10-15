import SwiftData
import SwiftUI

struct TripDashboard: View {
    let trip: Trip
    var showsClaim = false
    @Query private var trips: [Trip]
    @Environment(\.currencyCode) private var code
    @State private var isEditing = false
    @State private var newEntry: TripEntryRequest?

    var body: some View {
        let entries = (trip.entries ?? []).sorted { $0.date > $1.date }
        let summary = PeriodSummary(entries: entries, convertingTo: code)
        let status = trip.status()
        let chartInterval = chartInterval(days: summary.days)
        let chartDays = summary.days.filter { chartInterval.contains($0.day) }
        ScrollView {
            VStack(spacing: 18) {
                TripTitle(trip: trip)
                if status == .active {
                    MerSays(mood: .travelling)
                }
                SpentCard(title: "Spent on this trip", spent: summary.expense, prefix: summary.approximatePrefix)
                if status != .active {
                    Button("Start Trip", systemImage: "suitcase.rolling", action: start)
                        .font(.crayon(16, relativeTo: .body))
                        .buttonStyle(.glass)
                }
                if showsClaim, trip.isClaimable {
                    ClaimCard(summary: summary) { newEntry = TripEntryRequest(draft: .claim($0, trip: trip)) }
                }
                if !chartDays.isEmpty {
                    DailyCard(days: chartDays, interval: chartInterval, source: .trip(trip.uuid))
                }
                RecentCard(entries: entries) { TripEntries(trip: trip) }
                if trip.hasReceipts {
                    ReceiptsShareLink(trip: trip)
                        .font(.crayon(16, relativeTo: .body))
                        .buttonStyle(.glass)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Entry", systemImage: "plus") { newEntry = TripEntryRequest(draft: .new(trip: trip)) }
            }
        }
        .sheet(isPresented: $isEditing) { TripEditor(trip: trip) }
        .sheet(item: $newEntry) { EntryEditor($0.draft) }
    }

    private func start() {
        let now = Date.now
        for other in trips where other != trip && other.status(at: now) == .active {
            other.end = now
        }
        trip.start = now
        if let end = trip.end, end <= now { trip.end = nil }
        try? trip.modelContext?.save()
        Haptics.saved()
    }

    private func chartInterval(days: [DayTotal]) -> DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let first = trip.start.map(calendar.startOfDay) ?? days.first?.day ?? today
        let afterLast = calendar.date(byAdding: .day, value: 1, to: max(days.last?.day ?? first, today)) ?? today
        let end = trip.end ?? afterLast
        return DateInterval(start: first, end: max(end, calendar.date(byAdding: .day, value: 1, to: first) ?? end))
    }
}

private struct TripEntryRequest: Identifiable {
    let id = UUID()
    let draft: EntryDraft
}

private struct ClaimCard: View {
    let summary: PeriodSummary
    let logClaim: (Decimal) -> Void
    @Environment(\.currencyCode) private var code

    var body: some View {
        let outstanding = -summary.balance
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claim").cardTitle()
                Spacer()
                if outstanding > 0 {
                    Button("Log Claim") { logClaim(outstanding) }
                        .font(.crayon(15, relativeTo: .subheadline))
                }
            }
            HStack(alignment: .top) {
                figure("Claimed", summary.income, color: Palette.income)
                figure("Outstanding", outstanding, color: outstanding > 0 ? Palette.expense : Palette.ink)
            }
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sketchyCard(seed: 6)
    }

    private func figure(_ title: LocalizedStringKey, _ amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.crayon(13, relativeTo: .caption, bold: false))
                .foregroundStyle(Palette.pencil)
            Text(verbatim: summary.approximatePrefix + amount.money(code))
                .font(.crayon(20, relativeTo: .title3))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct TripEntries: View {
    let trip: Trip
    @Environment(\.currencyCode) private var code

    var body: some View {
        EntryDayList(entries: (trip.entries ?? []).sorted { $0.date > $1.date }, totals: .trip(mainCode: code)) {}
            .paperBackground()
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}
