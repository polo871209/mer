import SwiftData
import SwiftUI

struct BudgetView: View {
    @AppStorage(DefaultsKey.budgetEnabled) private var isEnabled = false
    @AppStorage(DefaultsKey.monthlyBudget) private var monthlyBudget = 0.0
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]
    @State private var amountText = ""

    var body: some View {
        Form {
            Section {
                Toggle("Monthly budget", isOn: $isEnabled.animation(.snappy))
            } footer: {
                Text("Home shows how much of the budget is left this month.")
            }

            if isEnabled {
                Section {
                    LabeledContent("Amount") {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Counts spending in your main account, \(Money.name(mainCurrency)).")
                }

                Section {
                    ForEach(categories.filter { $0.kind == .expense }) { BudgetCategoryRow(category: $0) }
                } header: {
                    Text("Counts in budget")
                } footer: {
                    Text("Turn off rent, tuition, or other fixed costs to keep them out of the budget. Trip entries never count in the budget.")
                }
            }
        }
        .paperBackground()
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            amountText = monthlyBudget > 0 ? Decimal(monthlyBudget).rounded(scale: Money.fractionDigits).formatted(.number.grouping(.never)) : ""
        }
        .onChange(of: amountText) {
            monthlyBudget = (try? Decimal(amountText, format: .number))?.double ?? 0
        }
    }
}

private struct BudgetCategoryRow: View {
    @Bindable var category: EntryCategory
    @Environment(\.modelContext) private var context

    var body: some View {
        Toggle(isOn: $category.isInBudget) {
            HStack(spacing: 12) {
                CategoryBadge(symbol: category.symbol, crayon: category.crayon, size: 34)
                Text(category.name).foregroundStyle(Palette.ink)
            }
        }
        .onChange(of: category.isInBudget) { try? context.save() }
    }
}

#Preview {
    NavigationStack { BudgetView() }
        .modelContainer(Store.preview)
}
