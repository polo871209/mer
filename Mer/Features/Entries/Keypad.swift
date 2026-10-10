import SwiftUI

struct Keypad: View {
    @Binding var text: String
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
                        let button = KeyButton(key: key) { text = KeypadInput.apply(key, to: text) }
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
