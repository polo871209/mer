import SwiftData
import SwiftUI

extension View {
    func searchesEntries() -> some View {
        modifier(EntrySearching())
    }
}

private struct EntrySearching: ViewModifier {
    @State private var isPresented = false
    @State private var text = ""
    @Environment(\.currencyCode) private var account

    func body(content: Content) -> some View {
        Group {
            if let search = EntrySearch(text) {
                EntrySearchResults(account: account, search: search)
            } else {
                content
            }
        }
        .modifier(PullDown { isPresented = true })
        .sensoryFeedback(.impact(weight: .light), trigger: isPresented) { _, isPresented in isPresented }
        .toolbarVisibility(isPresented ? .visible : .automatic, for: .navigationBar)
        // Attached only while open so iOS shows no search icon, and in a background so attaching it does not rebuild the content.
        .background {
            if isPresented {
                Color.clear.searchable(
                    text: $text,
                    isPresented: $isPresented,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Amount, category, or note"
                )
            }
        }
    }
}

private struct PullDown: ViewModifier {
    let action: () -> Void
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                isDragging = phase == .interacting
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top < -48
            } action: { _, isPulled in
                if isPulled, isDragging { action() }
            }
    }
}

private struct EntrySearchResults: View {
    let search: EntrySearch
    @Query private var entries: [Entry]

    init(account: String, search: EntrySearch) {
        self.search = search
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.accountCode == account }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.category, \.trip]
        _entries = Query(descriptor)
    }

    var body: some View {
        let matches = entries.filter(search.matches)
        EntryDayList(entries: matches) {
            if matches.isEmpty {
                MerEmptyState(title: "No matches", message: "Mer looked everywhere, even in the bowl.")
                    .padding(.top, 40)
            }
        }
    }
}

private struct EntrySearch {
    private let query: SearchQuery

    init?(_ text: String) {
        guard let query = SearchQuery(text) else { return nil }
        self.query = query
    }

    func matches(_ entry: Entry) -> Bool {
        let amounts = ([entry.amount] + [entry.originalAmount].compactMap(\.self)).flatMap(Self.amountTexts)
        return query.matches([entry.note, entry.category.displayName, entry.trip?.name ?? ""]) { term in
            guard let number = Self.numberText(term) else { return false }
            return amounts.contains { $0.hasPrefix(number) }
        }
    }

    private static func amountTexts(_ amount: Decimal) -> [String] {
        let precision = Decimal.FormatStyle.number.precision(.fractionLength(2...))
        let fixed = amount.formatted(precision.grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
        return [fixed, fixed.replacing(".", with: ","), amount.formatted(precision), amount.description]
    }

    private static func numberText(_ term: String) -> String? {
        let kept = term.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }
        return kept.contains(where: \.isNumber) ? kept : nil
    }
}
