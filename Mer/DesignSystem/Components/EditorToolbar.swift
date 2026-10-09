import SwiftUI

struct EditorDeletion {
    let question: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    var message: LocalizedStringKey?
    let action: () -> Void
}

extension View {
    func editorToolbar(canSave: Bool, save: @escaping () -> Void, deletion: EditorDeletion? = nil) -> some View {
        modifier(EditorToolbar(canSave: canSave, save: save, deletion: deletion))
    }
}

private struct EditorToolbar: ViewModifier {
    let canSave: Bool
    let save: () -> Void
    let deletion: EditorDeletion?
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) { dismiss() }
            }
            if let deletion {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                        .confirmationDialog(deletion.question, isPresented: $isConfirmingDelete) {
                            Button(deletion.confirmTitle, role: .destructive) {
                                dismiss()
                                deletion.action()
                                Haptics.deleted()
                            }
                        } message: {
                            if let message = deletion.message { Text(message) }
                        }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", role: .confirm) {
                    save()
                    Haptics.saved()
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .presentationDragIndicator(.visible)
    }
}
