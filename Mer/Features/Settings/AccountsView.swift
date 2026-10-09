import SwiftData
import SwiftUI

struct AccountsView: View {
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.otherCurrencies) private var otherCurrencies = ""
    @Query private var entries: [Entry]
    @State private var isAddingAccount = false
    @State private var isPickingMainAccount = false

    var body: some View {
        let accounts = Accounts(main: mainCurrency, storedOthers: otherCurrencies)
        let balances = entries.reduce(into: [String: Decimal]()) { $0[$1.accountCode, default: 0] += $1.signedAmount }
        Form {
            Section {
                Button {
                    isPickingMainAccount = true
                } label: {
                    LabeledContent("Main account", value: Money.name(accounts.main))
                        .foregroundStyle(Palette.ink)
                }
                .sheet(isPresented: $isPickingMainAccount) {
                    CurrencyPicker(selection: accounts.main) { save(accounts.makingMain($0)) }
                }
            } footer: {
                Text("Home and Report show the main account. Money in a currency without its own account converts into the main account.")
            }

            Section("Balances") {
                ForEach(accounts.all + orphanedCodes(accounts), id: \.self) { code in
                    let status: AccountStatus = code == accounts.main ? .main : accounts.others.contains(code) ? .other : .removed
                    NavigationLink {
                        ReportView()
                            .environment(\.currencyCode, code)
                            .navigationTitle(Money.name(code))
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        AccountRow(code: code, status: status, balance: balances[code] ?? 0)
                    }
                    .swipeActions {
                        if status == .other {
                            Button("Remove", systemImage: "minus.circle", role: .destructive) {
                                save(accounts.removing(code))
                                Haptics.deleted()
                            }
                        }
                    }
                }
                Button("Add Account", systemImage: "plus") { isAddingAccount = true }
                    .sheet(isPresented: $isAddingAccount) {
                        CurrencyPicker(selection: nil) { save(accounts.adding($0)) }
                    }
            }
        }
        .paperBackground()
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save(_ accounts: Accounts) {
        mainCurrency = accounts.main
        otherCurrencies = accounts.storedOthers
    }

    private func orphanedCodes(_ accounts: Accounts) -> [String] {
        Set(entries.map(\.accountCode)).subtracting(accounts.all).sorted()
    }
}

private enum AccountStatus {
    case main, other, removed
}

private struct AccountRow: View {
    let code: String
    let status: AccountStatus
    let balance: Decimal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Money.name(code))
                if status == .removed {
                    Text("Removed")
                        .font(.caption)
                        .foregroundStyle(Palette.pencil)
                }
            }
            Spacer(minLength: 8)
            Text(balance.signedMoney(code))
                .font(.crayon(17, relativeTo: .body))
                .foregroundStyle(balance < 0 ? Palette.expense : Palette.income)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AccountsView()
    }
    .modelContainer(Store.preview)
}
