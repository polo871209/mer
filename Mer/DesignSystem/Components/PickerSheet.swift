import SwiftUI

extension View {
    /// The layout every picker and list sheet uses: inline title, close button, paper background, and medium and large heights.
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
