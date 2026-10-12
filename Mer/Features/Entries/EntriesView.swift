import SwiftData
import SwiftUI

struct EntriesView: View {
    @State private var month: Date
    @State private var day: Date?
    @Environment(\.currencyCode) private var account

    init(month: Date) {
        _month = State(initialValue: month)
    }

    var body: some View {
        MonthEntries(account: account, month: $month, day: $day)
            .searchesEntries()
            .paperBackground()
            .navigationTitle("Entries")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MonthEntries: View {
    @Query private var entries: [Entry]
    @Binding private var month: Date
    @Binding private var day: Date?
    @State private var isPickingDay = false

    init(account: String, month: Binding<Date>, day: Binding<Date?>) {
        let interval =
            day.wrappedValue.flatMap { Calendar.current.dateInterval(of: .day, for: $0) }
            ?? Period.month.interval(containing: month.wrappedValue)
        let start = interval.start
        let end = interval.end
        _month = month
        _day = day
        _entries = Query(
            filter: #Predicate<Entry> { $0.accountCode == account && $0.date >= start && $0.date < end },
            sort: \Entry.date,
            order: .reverse
        )
    }

    var body: some View {
        EntryDayList(entries: entries) {
            PeriodPicker(period: .month, date: wholeMonth) { isPickingDay = true }
            if let day {
                Button {
                    withAnimation(.snappy) { self.day = nil }
                } label: {
                    HStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                    }
                    .font(.crayon(15, relativeTo: .subheadline))
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Show Whole Month")
                .accessibilityValue(Text(day, format: .dateTime.weekday(.wide).month(.wide).day()))
            }
            if entries.isEmpty {
                MerEmptyState(title: "No entries", message: day == nil ? "Tap + to log money in or out for this month." : "Nothing logged here.")
                    .padding(.top, 40)
            }
        }
        .sheet(isPresented: $isPickingDay) {
            MonthCalendar(month: day ?? month, selection: day) { picked in
                withAnimation(.snappy) {
                    if let day, Calendar.current.isDate(day, inSameDayAs: picked) {
                        self.day = nil
                    } else {
                        month = Period.month.interval(containing: picked).start
                        self.day = picked
                    }
                }
            }
        }
    }

    private var wholeMonth: Binding<Date> {
        Binding {
            month
        } set: {
            month = $0
            day = nil
        }
    }
}

#Preview {
    NavigationStack {
        EntriesView(month: .now)
    }
    .modelContainer(Store.preview)
}
