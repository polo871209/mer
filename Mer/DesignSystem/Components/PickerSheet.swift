import SwiftUI

extension View {
    func pickerSheet(_ title: Text) -> some View {
        modifier(PickerSheet(title: title))
    }
}

private struct PickerSheet: ViewModifier {
    let title: Text
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        NavigationStack {
            content
                .foregroundStyle(Palette.ink)
                .paperBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
