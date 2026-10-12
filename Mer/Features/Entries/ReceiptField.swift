import PhotosUI
import SwiftUI

struct ReceiptField: View {
    @Binding var receipt: Data?
    @State private var isTakingPhoto = false
    @State private var isChoosingPhoto = false
    @State private var isViewing = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        Menu {
            if let receipt {
                Button("View Receipt", systemImage: "eye") { isViewing = true }
                ShareLink("Share Receipt", item: ReceiptPhoto(data: receipt), preview: SharePreview("Receipt"))
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera") { isTakingPhoto = true }
            }
            Button("Choose Photo", systemImage: "photo.on.rectangle") { isChoosingPhoto = true }
            if receipt != nil {
                Button("Remove Receipt", systemImage: "trash", role: .destructive) { receipt = nil }
            }
        } label: {
            Image(systemName: receipt == nil ? "receipt" : "receipt.fill")
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    SketchyBackground(fill: receipt == nil ? Palette.card : Crayon.butter.color.opacity(0.45), seed: 53, cornerRadius: 10)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Receipt")
        .accessibilityValue(receipt == nil ? String(localized: "None") : String(localized: "Attached"))
        .photosPicker(isPresented: $isChoosingPhoto, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $isTakingPhoto) {
            CameraPicker { image in
                Task { attach(await ReceiptImage.jpeg(from: image)) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isViewing) {
            if let receipt { ReceiptViewer(data: receipt) }
        }
        .task(id: pickedItem) {
            guard let pickedItem, let data = try? await pickedItem.loadTransferable(type: Data.self) else { return }
            self.pickedItem = nil
            attach(await ReceiptImage.jpeg(from: data))
        }
    }

    private func attach(_ jpeg: Data?) {
        guard let jpeg else { return }
        receipt = jpeg
        Haptics.picked()
    }
}

private struct ReceiptViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let image = UIImage(data: data)
        NavigationStack {
            ScrollView {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Receipt photo")
                        .padding()
                }
            }
            .paperBackground()
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                if let image {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: ReceiptPhoto(data: data),
                            preview: SharePreview("Receipt", image: Image(uiImage: image))
                        )
                    }
                }
            }
        }
    }
}

private nonisolated struct ReceiptPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
            .suggestedFileName("Receipt.jpg")
    }
}

// SwiftUI has no camera view, so this wraps UIKit's.
private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private nonisolated enum ReceiptImage {
    @concurrent static func jpeg(from data: Data) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return await jpeg(from: image)
    }

    @concurrent static func jpeg(from image: UIImage) async -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.7) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
