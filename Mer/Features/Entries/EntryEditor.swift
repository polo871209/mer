import SwiftData
import SwiftUI

struct EntryEditor: View {
    private let entry: Entry?
    @Environment(\.modelContext) private var context
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.otherCurrencies) private var otherCurrencies = ""
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]
    @State private var kind: EntryKind
    @State private var digits: String
    @State private var currency: String
    @State private var isPickingCurrency = false
    @State private var category: EntryCategory?
    @State private var note: String
    @State private var date: Date
    @FocusState private var isEditingNote: Bool

    init(entry: Entry?) {
        self.entry = entry
        _kind = State(initialValue: entry?.kind ?? .expense)
        _digits = State(initialValue: entry?.typedAmount.description ?? "")
        _currency = State(initialValue: entry?.typedCode ?? Money.mainCode)
        _category = State(initialValue: entry?.category)
        _note = State(initialValue: entry?.note ?? "")
        _date = State(initialValue: entry?.date ?? .now)
    }

    private var choices: [EntryCategory] { categories.filter { $0.kind == kind } }

    var body: some View {
        let accounts = Accounts(main: mainCurrency, storedOthers: otherCurrencies)
        let account = accounts.account(for: currency)
        let fractionDigits = Money.fractionDigits(currency)
        let amount = KeypadInput.amount(digits, fractionDigits: fractionDigits)
        let conversion = account == currency ? nil : Conversion(account: account, rate: savedOrLatestRate(to: account))
        let accountAmount = if let conversion { amount.flatMap(conversion.convert) } else { amount }
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Type", selection: $kind) {
                    ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                amountDisplay(amount, fractionDigits: fractionDigits, conversion: conversion, accountAmount: accountAmount)

                HStack(spacing: 10) {
                    CategoryField(categories: choices, selection: $category)
                    DateField(date: $date)
                }

                HStack(spacing: 10) {
                    TextField("Add note", text: $note)
                        .focused($isEditingNote)
                        .submitLabel(.done)
                        .onSubmit { isEditingNote = false }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background { SketchyBackground(seed: 40, cornerRadius: 10) }
                    // The keyboard's Done key is missing when a hardware keyboard is attached.
                    if isEditingNote {
                        Button("Done") { isEditingNote = false }
                            .font(.crayon(17, relativeTo: .body))
                    }
                }

                Spacer(minLength: 0)

                if !isEditingNote {
                    Keypad(text: $digits, fractionDigits: fractionDigits)
                }
            }
            .padding()
            .foregroundStyle(Palette.ink)
            .paperBackground()
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .editorToolbar(
                canSave: amount != nil && accountAmount != nil,
                save: { save(amount, accountAmount: accountAmount, account: account) },
                deletion: entry.map { entry in
                    EditorDeletion(question: "Delete this entry?", confirmTitle: "Delete Entry") { context.delete(entry) }
                }
            )
            .onChange(of: kind) {
                if category?.kind != kind { category = choices.first }
            }
            .onAppear {
                if entry == nil, category == nil { category = choices.first }
            }
            .task(id: currency) {
                if account != currency { await ExchangeRates.shared.refreshIfStale() }
            }
            .sheet(isPresented: $isPickingCurrency) {
                CurrencyPicker(selection: currency) { currency = $0 }
            }
        }
    }

    private func amountDisplay(_ amount: Decimal?, fractionDigits: Int, conversion: Conversion?, accountAmount: Decimal?) -> some View {
        VStack(spacing: 2) {
            expression
            if KeypadInput.hasOperator(digits) {
                Text(verbatim: "= " + (KeypadInput.evaluate(digits)?.rounded(scale: fractionDigits).money(currency) ?? "?"))
                    .font(.crayon(18, relativeTo: .headline, bold: false))
                    .foregroundStyle(amount == nil ? Palette.expense : Palette.pencil)
            }
            if let conversion {
                conversionLine(conversion, accountAmount: accountAmount)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .animation(.snappy, value: digits)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue((amount ?? 0).money(currency))
        .accessibilityAction(named: "Change Currency") { isPickingCurrency = true }
    }

    private func conversionLine(_ conversion: Conversion, accountAmount: Decimal?) -> some View {
        Group {
            if let rate = conversion.rate {
                let rateText = "1 \(currency) ≈ \(rate.formatted(.number.precision(.significantDigits(1...4)))) \(conversion.account)"
                Text(verbatim: "≈ \((accountAmount ?? 0).money(conversion.account)) · \(rateText)")
                    .foregroundStyle(Palette.pencil)
            } else {
                Text("No exchange rate yet. Connect to the internet to convert into \(conversion.account).")
                    .foregroundStyle(Palette.expense)
            }
        }
        .font(.crayon(15, relativeTo: .subheadline, bold: false))
        .multilineTextAlignment(.center)
    }

    private func savedOrLatestRate(to account: String) -> Decimal? {
        if let entry, let original = entry.originalAmount, original > 0, entry.originalCode == currency, entry.accountCode == account {
            return entry.amount / original
        }
        return ExchangeRates.shared.rate(from: currency, to: account)
    }

    private var expression: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: kind == .expense ? "-" : "+")
                .font(.crayon(34, relativeTo: .largeTitle))
                .foregroundStyle(kind == .expense ? Palette.expense : Palette.income)
            Text(KeypadInput.display(digits))
                .font(.crayon(56, relativeTo: .largeTitle))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
            Button {
                isPickingCurrency = true
            } label: {
                HStack(spacing: 4) {
                    Text(currency)
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                }
                .font(.crayon(18, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { SketchyBackground(fill: Crayon.butter.color.opacity(0.35), seed: 60, cornerRadius: 10) }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Currency")
            .accessibilityValue(Money.name(currency))
        }
    }

    private func save(_ amount: Decimal?, accountAmount: Decimal?, account: String) {
        guard let amount, let accountAmount else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Entry
        if let entry {
            target = entry
        } else {
            target = Entry(amount: accountAmount, accountCode: account, kind: kind)
            context.insert(target)
        }
        let isConverted = account != currency
        target.amount = accountAmount
        target.accountCode = account
        target.originalAmount = isConverted ? amount : nil
        target.originalCode = isConverted ? currency : nil
        target.kind = kind
        target.note = trimmedNote
        target.category = category
        target.date = date
    }
}

private struct Conversion {
    let account: String
    let rate: Decimal?

    func convert(_ amount: Decimal) -> Decimal? {
        guard let rate else { return nil }
        let converted = (amount * rate).rounded(scale: Money.fractionDigits(account))
        return converted > 0 ? converted : nil
    }
}

private struct CategoryField: View {
    let categories: [EntryCategory]
    @Binding var selection: EntryCategory?
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            HStack(spacing: 10) {
                CategoryBadge(category: selection, size: 32)
                Text(selection.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Palette.pencil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background { SketchyBackground(seed: 45, cornerRadius: 10) }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Category")
        .accessibilityValue(selection.displayName)
        .sheet(isPresented: $isPicking) {
            CategoryPicker(categories: categories, selection: $selection)
        }
    }
}

private struct CategoryPicker: View {
    let categories: [EntryCategory]
    @Binding var selection: EntryCategory?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 12) {
                ForEach(categories) { category in
                    let isSelected = selection == category
                    Button {
                        selection = category
                        Haptics.picked()
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            CategoryBadge(symbol: category.symbol, crayon: category.crayon, size: 48)
                                .overlay {
                                    if isSelected {
                                        SketchyEllipse(seed: 13).stroke(Palette.ink, lineWidth: 3).padding(-5)
                                    }
                                }
                            Text(category.name)
                                .font(.caption.weight(isSelected ? .bold : .regular))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding()
        }
        .pickerSheet(Text("Category"))
    }
}

private struct Keypad: View {
    @Binding var text: String
    let fractionDigits: Int
    private static let rows: [[KeypadKey]] = [
        [.digit(7), .digit(8), .digit(9), .op(.divide)],
        [.digit(4), .digit(5), .digit(6), .op(.multiply)],
        [.digit(1), .digit(2), .digit(3), .op(.subtract)],
        [.dot, .digit(0), .delete, .op(.add)],
    ]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        let button = KeyButton(key: key) { text = KeypadInput.apply(key, to: text, fractionDigits: fractionDigits) }
                        if key == .delete {
                            button
                                .simultaneousGesture(LongPressGesture().onEnded { _ in text = "" })
                                .accessibilityAction(named: "Clear") { text = "" }
                        } else {
                            button
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: text)
    }
}

private struct KeyButton: View {
    let key: KeypadKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.crayon(26, relativeTo: .title2))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background { SketchyBackground(fill: isOperator ? Crayon.butter.color.opacity(0.35) : Palette.card, seed: seed, cornerRadius: 14) }
        }
        .buttonStyle(PressScale())
    }

    @ViewBuilder private var label: some View {
        switch key {
        case .digit(let digit): Text(verbatim: "\(digit)")
        case .dot: Text(verbatim: Locale.current.decimalSeparator ?? ".").accessibilityLabel("Decimal point")
        case .delete: Image(systemName: "delete.left").accessibilityLabel("Delete")
        // Chalkboard draws "×" and "−" as scribbles, so operators use SF Symbols.
        case .op(let op): Image(systemName: op.symbolName).fontWeight(.semibold).accessibilityLabel(op.label)
        }
    }

    private var isOperator: Bool {
        if case .op = key { true } else { false }
    }

    private var seed: UInt64 {
        switch key {
        case .digit(let digit): UInt64(digit + 1) &* 7
        case .dot: 101
        case .delete: 103
        case .op(let op): String(op.rawValue).stableSeed
        }
    }
}

extension KeypadOperator {
    fileprivate var symbolName: String {
        switch self {
        case .add: "plus"
        case .subtract: "minus"
        case .multiply: "multiply"
        case .divide: "divide"
        }
    }

    fileprivate var label: LocalizedStringKey {
        switch self {
        case .add: "Plus"
        case .subtract: "Minus"
        case .multiply: "Times"
        case .divide: "Divided by"
        }
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    EntryEditor(entry: nil)
        .modelContainer(Store.preview)
}
