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
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }
}

struct EntryDayList<Top: View>: View {
    let entries: [Entry]
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
                        .swipeToDelete { context.delete(entry) }
                    }
                } header: {
                    HStack {
                        Text(group.day, format: dayFormat(group.day))
                        Spacer()
                        Text(group.entries.reduce(Decimal.zero) { $0 + $1.signedAmount }.signedMoney(group.entries[0].accountCode))
                    }
                    .font(.crayon(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.pencil)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }

    private var groupedByDay: [(day: Date, entries: [Entry])] {
        let calendar = Calendar.current
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
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
            CategoryBadge(category: entry.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
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

    private var subtitle: String {
        let name = entry.note.isEmpty ? nil : entry.category?.name
        let date = entry.date.formatted(.dateTime.month(.abbreviated).day())
        let original = entry.originalCode.map { entry.typedAmount.money($0) }
        return [name, date, original].compactMap(\.self).joined(separator: " · ")
    }
}
