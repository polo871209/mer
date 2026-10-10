import SwiftData
import SwiftUI

struct EntryList: View {
    let entries: [Entry]
    @State private var editing: Entry?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(entries) { entry in
                Button {
                    editing = entry
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $editing) { EntryEditor(.edit($0)) }
    }
}

enum DayTotals {
    case account
    case trip(mainCode: String)
}

extension EntrySource {
    func dayTotals(mainCode: String) -> DayTotals {
        switch self {
        case .account: .account
        case .trip: .trip(mainCode: mainCode)
        }
    }
}

struct EntryDayList<Top: View>: View {
    let entries: [Entry]
    var totals = DayTotals.account
    @ViewBuilder let top: Top
    @Environment(\.modelContext) private var context
    @State private var editing: Entry?
    var body: some View {
        List {
            Group { top }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button {
                            editing = entry
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(entry)
                                try? context.save()
                                Haptics.deleted()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.day, format: dayFormat(group.day))
                        Spacer()
                        dayTotal(group.entries)
                    }
                    .font(.crayon(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.pencil)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: $editing) { EntryEditor(.edit($0)) }
    }

    private var groupedByDay: [(day: Date, entries: [Entry])] {
        let calendar = Calendar.current
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
    }

    @ViewBuilder private func dayTotal(_ entries: [Entry]) -> some View {
        switch totals {
        case .account:
            let counted = entries.filter { $0.trip == nil }
            if let code = counted.first?.accountCode {
                Text(counted.reduce(Decimal.zero) { $0 + $1.signedAmount }.signedMoney(code))
            }
        case .trip(let mainCode):
            let summary = PeriodSummary(entries: entries, convertingTo: mainCode)
            Text(verbatim: summary.approximatePrefix + summary.balance.signedMoney(mainCode))
        }
    }

    private func dayFormat(_ day: Date) -> Date.FormatStyle {
        let format = Date.FormatStyle.dateTime.weekday(.wide).day().month()
        return Calendar.current.isDate(day, equalTo: .now, toGranularity: .year) ? format : format.year()
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(symbol: entry.category.displaySymbol, crayon: entry.category.displayCrayon)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                subtitle
                    .font(.caption)
                    .foregroundStyle(Palette.pencil)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(entry.signedAmount.signedMoney(entry.accountCode))
                .font(.crayon(17, relativeTo: .body))
                .foregroundStyle(entry.kind == .income ? Palette.income : Palette.ink)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: Text {
        let name = entry.note.isEmpty ? nil : entry.category?.name
        let date = entry.date.formatted(.dateTime.month(.abbreviated).day())
        let original = entry.originalCode.map { entry.typedAmount.money($0) }
        let details = Text(verbatim: [name, date, original].compactMap(\.self).joined(separator: " · "))
        guard let trip = entry.trip else { return details }
        return Text("\(Image(systemName: "suitcase.rolling")) \(trip.name) · \(details)")
    }
}
