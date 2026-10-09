import SwiftUI

struct CurrencyPicker: View {
    let selection: String?
    let pick: (String) -> Void
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.otherCurrencies) private var otherCurrencies = ""
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        let accounts = Accounts(main: mainCurrency, storedOthers: otherCurrencies).all
        List {
            if let query = SearchQuery(search) {
                rows(Locale.commonISOCurrencyCodes.filter { query.matches([$0, Money.name($0)]) })
            } else {
                Section("Accounts") { rows(accounts) }
                Section("Other currencies") { rows(Locale.commonISOCurrencyCodes.filter { !accounts.contains($0) }) }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Name or code")
        .pickerSheet(Text("Currency"))
    }

    private func rows(_ codes: [String]) -> some View {
        ForEach(codes, id: \.self) { code in
            Button {
                pick(code)
                Haptics.picked()
                dismiss()
            } label: {
                HStack {
                    Text(Money.name(code)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(code).foregroundStyle(Palette.pencil)
                    if code == selection {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .accessibilityAddTraits(code == selection ? .isSelected : [])
        }
    }
}
