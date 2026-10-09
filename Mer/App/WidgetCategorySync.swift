import SwiftData
import SwiftUI
import WidgetKit

struct WidgetCategorySync: ViewModifier {
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]

    func body(content: Content) -> some View {
        let expensesFirst = categories.filter { $0.kind == .expense } + categories.filter { $0.kind == .income }
        let shortcuts = expensesFirst.map { CategoryShortcut(id: $0.uuid, name: $0.name, symbol: $0.symbol, crayon: $0.crayon) }
        content.task(id: shortcuts) {
            guard CategoryShortcut.all != shortcuts else { return }
            CategoryShortcut.all = shortcuts
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
