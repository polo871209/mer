import SwiftData
import SwiftUI

struct EntriesView: View {
    @State private var month = Calendar.current.monthInterval(containing: .now).start
    @State private var search = ""

    var body: some View {
        EntryList(month: $month, search: $search)
            .background { PaperBackground() }
    }
}

private struct EntryList: View {
    @Query private var entries: [Entry]
    @Environment(\.modelContext) private var context
    @Environment(\.currencyCode) private var code
    @State private var editing: Entry?
    @State private var deletions = 0
    @Binding private var month: Date
    @Binding private var search: String

    init(month: Binding<Date>, search: Binding<String>) {
        let interval = Calendar.current.monthInterval(containing: month.wrappedValue)
        let start = interval.start
        let end = interval.end
        _month = month
        _search = search
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    var body: some View {
        let days = groupedByDay
        List {
            MonthPicker(month: $month)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            SearchField(text: $search)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if days.isEmpty {
                Group {
                    if search.isEmpty {
                        MerEmptyState(title: "No entries", message: "Tap + to log money in or out for this month.")
                    } else {
                        MerEmptyState(title: "No matches", message: "Mer looked everywhere, even in the bowl.")
                    }
                }
                .padding(.top, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(days, id: \.day) { group in
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
                                deletions += 1
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.day, format: .dateTime.weekday(.wide).day().month())
                        Spacer()
                        Text(group.entries.reduce(Decimal.zero) { $0 + $1.signedAmount }.signedMoney(code))
                    }
                    .font(.crayon(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.pencil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .sensoryFeedback(.impact(weight: .medium), trigger: deletions)
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }

    private var groupedByDay: [(day: Date, entries: [Entry])] {
        let calendar = Calendar.current
        let matches =
            search.isEmpty
            ? entries
            : entries.filter {
                $0.note.localizedStandardContains(search) || ($0.category?.name.localizedStandardContains(search) ?? false)
            }
        return Dictionary(grouping: matches) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.pencil)
            TextField("Note or category", text: $text)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Palette.pencil)
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background { SketchyBackground(seed: 70, cornerRadius: 10) }
    }
}

#Preview {
    EntriesView()
        .modelContainer(Store.preview)
}
