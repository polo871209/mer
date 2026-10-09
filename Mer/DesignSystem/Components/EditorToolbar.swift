import SwiftUI

struct EditorDeletion {
    let question: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    var message: LocalizedStringKey?
    let action: () -> Void
}

extension View {
    /// The toolbar every editor sheet uses: close, delete after confirmation when `deletion` is set, and save. Each action dismisses the sheet.
    func editorToolbar(canSave: Bool, save: @escaping () -> Void, deletion: EditorDeletion? = nil) -> some View {
        modifier(EditorToolbar(canSave: canSave, save: save, deletion: deletion))
    }

    /// The swipe action every list uses to delete a row.
    func swipeToDelete(_ delete: @escaping () -> Void) -> some View {
        swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                delete()
                Haptics.deleted()
            }
        }
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
                                deletion.action()
                                Haptics.deleted()
                                dismiss()
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
