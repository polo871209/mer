import SwiftData
import SwiftUI
import UIKit

struct EntryEditor: View {
    private let entry: Entry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.currencyCode) private var code
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]
    @State private var kind: EntryKind
    @State private var digits: String
    @State private var category: EntryCategory?
    @State private var note: String
    @FocusState private var isEditingNote: Bool

    init(entry: Entry?) {
        self.entry = entry
        _kind = State(initialValue: entry?.kind ?? .expense)
        _digits = State(initialValue: entry?.amount.plainString ?? "")
        _category = State(initialValue: entry?.category)
        _note = State(initialValue: entry?.note ?? "")
    }

    private var choices: [EntryCategory] { categories.filter { $0.kind == kind } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Type", selection: $kind) {
                    ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                amountDisplay

                CategoryField(categories: choices, selection: $category)

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
                    Keypad(text: $digits)
                }
            }
            .padding()
            .foregroundStyle(Palette.ink)
            .background { PaperBackground() }
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", role: .confirm) { save() }
                        .disabled(KeypadInput.amount(digits) == nil)
                }
            }
            .onChange(of: kind) {
                if category?.kind != kind { category = choices.first }
            }
            .onAppear {
                if category == nil { category = choices.first }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var amountDisplay: some View {
        VStack(spacing: 2) {
            expression
            if KeypadInput.hasOperator(digits) {
                Text(verbatim: "= " + (KeypadInput.evaluate(digits)?.rounded(scale: 2).money(code) ?? "?"))
                    .font(.crayon(18, relativeTo: .headline, bold: false))
                    .foregroundStyle(KeypadInput.amount(digits) == nil ? Palette.expense : Palette.pencil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .animation(.snappy, value: digits)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue((KeypadInput.amount(digits) ?? 0).money(code))
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
            Text(code)
                .font(.crayon(18, relativeTo: .headline, bold: false))
                .foregroundStyle(Palette.pencil)
        }
    }

    private func save() {
        guard let amount = KeypadInput.amount(digits) else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Entry
        if let entry {
            target = entry
        } else {
            target = Entry(amount: amount, kind: kind)
            context.insert(target)
        }
        target.amount = amount
        target.kind = kind
        target.note = trimmedNote
        target.category = category
        // The sheet dismisses right away, so a `.sensoryFeedback` trigger on it would never fire.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
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
                CategoryBadge(symbol: selection?.symbol ?? "questionmark", crayon: selection?.crayon ?? .cocoa, size: 32)
                Text(selection?.name ?? String(localized: "Uncategorized"))
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
        .accessibilityValue(selection?.name ?? String(localized: "Uncategorized"))
        .sensoryFeedback(.selection, trigger: selection)
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
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 12) {
                    ForEach(categories) { category in
                        let isSelected = selection == category
                        Button {
                            selection = category
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
            .foregroundStyle(Palette.ink)
            .background { PaperBackground() }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct Keypad: View {
    @Binding var text: String
    private let rows: [[KeypadKey]] = [
        [.digit(7), .digit(8), .digit(9), .op(.divide)],
        [.digit(4), .digit(5), .digit(6), .op(.multiply)],
        [.digit(1), .digit(2), .digit(3), .op(.subtract)],
        [.dot, .digit(0), .delete, .op(.add)],
    ]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row], id: \.self) { key in
                        KeyButton(key: key) { text = KeypadInput.apply(key, to: text) }
                            .simultaneousGesture(
                                LongPressGesture().onEnded { _ in
                                    if key == .delete { text = "" }
                                })
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
        case .op(let op): 107 &+ UInt64(op.rawValue.unicodeScalars.first!.value)
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
