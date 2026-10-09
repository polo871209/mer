import SwiftData
import SwiftUI

struct EntriesSheet: View {
    let title: String
    @Query private var entries: [Entry]

    init(title: String, account: String, interval: DateInterval) {
        let start = interval.start
        let end = interval.end
        self.init(title: title, filter: #Predicate { $0.accountCode == account && $0.date >= start && $0.date < end })
    }

    /// Lists the expenses of `account` in `interval` whose category has `categoryID`, or that have no category when `categoryID` is `nil`.
    init(title: String, account: String, interval: DateInterval, expensesIn categoryID: UUID?) {
        let start = interval.start
        let end = interval.end
        let expense = EntryKind.expense.rawValue
        let filter: Predicate<Entry>
        if let categoryID {
            filter = #Predicate {
                $0.accountCode == account && $0.date >= start && $0.date < end && $0.kindRaw == expense && $0.category?.uuid == categoryID
            }
        } else {
            filter = #Predicate {
                $0.accountCode == account && $0.date >= start && $0.date < end && $0.kindRaw == expense && $0.category == nil
            }
        }
        self.init(title: title, filter: filter)
    }

    private init(title: String, filter: Predicate<Entry>) {
        self.title = title
        _entries = Query(filter: filter, sort: \Entry.date, order: .reverse)
    }

    var body: some View {
        EntryDayList(entries: entries) {
            if entries.isEmpty {
                MerEmptyState(title: "No entries", message: "Nothing logged here.")
            }
        }
        .pickerSheet(Text(verbatim: title))
    }
}
