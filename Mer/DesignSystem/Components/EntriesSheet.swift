import SwiftData
import SwiftUI

struct EntriesSheet: View {
    let title: String
    private let source: EntrySource
    @Query private var entries: [Entry]
    @Environment(\.currencyCode) private var code

    init(title: String, source: EntrySource, interval: DateInterval) {
        let start = interval.start
        let end = interval.end
        let all = source.all
        self.init(title: title, source: source, filter: #Predicate { all.evaluate($0) && $0.date >= start && $0.date < end })
    }

    init(title: String, source: EntrySource, interval: DateInterval, expensesIn categoryID: UUID?) {
        let start = interval.start
        let end = interval.end
        let expense = EntryKind.expense.rawValue
        let counted = source.counted
        let filter: Predicate<Entry>
        if let categoryID {
            filter = #Predicate {
                counted.evaluate($0) && $0.date >= start && $0.date < end && $0.kindRaw == expense && $0.category?.uuid == categoryID
            }
        } else {
            filter = #Predicate {
                counted.evaluate($0) && $0.date >= start && $0.date < end && $0.kindRaw == expense && $0.category == nil
            }
        }
        self.init(title: title, source: source, filter: filter)
    }

    private init(title: String, source: EntrySource, filter: Predicate<Entry>) {
        self.title = title
        self.source = source
        _entries = Query(filter: filter, sort: \Entry.date, order: .reverse)
    }

    var body: some View {
        EntryDayList(entries: entries, totals: source.dayTotals(mainCode: code)) {
            if entries.isEmpty {
                MerEmptyState(title: "No entries", message: "Nothing logged here.")
            }
        }
        .pickerSheet(Text(verbatim: title))
    }
}
