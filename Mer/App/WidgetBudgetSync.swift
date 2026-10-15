import SwiftData
import SwiftUI
import WidgetKit

struct WidgetBudgetSync: ViewModifier {
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @State private var month = Date.now

    func body(content: Content) -> some View {
        content
            .background { BudgetSnapshotWriter(month: Period.month.interval(containing: month), account: mainCurrency) }
            .followsCurrentPeriod($month, period: .month)
    }
}

private struct BudgetSnapshotWriter: View {
    @Query private var entries: [Entry]
    @AppStorage(DefaultsKey.budgetEnabled) private var budgetEnabled = false
    @AppStorage(DefaultsKey.monthlyBudget) private var monthlyBudget = 0.0
    private let month: DateInterval
    private let account: String

    init(month: DateInterval, account: String) {
        self.month = month
        self.account = account
        _entries = Query(filter: BudgetSnapshot.entries(in: month, account: account))
    }

    var body: some View {
        let limit = MonthlyBudget.limit(isOn: budgetEnabled, stored: monthlyBudget)
        let snapshot = BudgetSnapshot(month: month, account: account, entries: entries, limit: limit)
        Color.clear.task(id: snapshot) { snapshot.publish() }
    }
}

extension BudgetSnapshot {
    @MainActor
    static func refresh(in context: ModelContext) {
        let month = Period.month.interval(containing: .now)
        let account = Money.mainCode
        let defaults = UserDefaults.standard
        let limit = MonthlyBudget.limit(isOn: defaults.bool(forKey: DefaultsKey.budgetEnabled), stored: defaults.double(forKey: DefaultsKey.monthlyBudget))
        guard let entries = try? context.fetch(FetchDescriptor(predicate: entries(in: month, account: account))) else { return }
        BudgetSnapshot(month: month, account: account, entries: entries, limit: limit).publish()
    }

    fileprivate static func entries(in month: DateInterval, account: String) -> Predicate<Entry> {
        let start = month.start
        let end = month.end
        return #Predicate { $0.accountCode == account && $0.date >= start && $0.date < end }
    }

    fileprivate init(month: DateInterval, account: String, entries: [Entry], limit: Decimal?) {
        let counted = entries.filter { $0.kind == .expense && (limit == nil ? $0.trip == nil : $0.countsInBudget) }
        self.init(month: month.start, spent: counted.reduce(Decimal.zero) { $0 + $1.amount }, limit: limit)
    }

    fileprivate func publish() {
        guard Self.stored != self else { return }
        save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
