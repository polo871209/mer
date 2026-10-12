import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ReceiptsShareLink: View {
    let trip: Trip
    @Environment(\.modelContext) private var context

    var body: some View {
        let receipts = TripReceipts(container: context.container, tripID: trip.uuid, tripName: trip.name)
        ShareLink(item: receipts, preview: SharePreview(receipts.zipName)) {
            Label("Export Receipts", systemImage: "square.and.arrow.up")
        }
    }
}

private nonisolated struct TripReceipts: Transferable {
    let container: ModelContainer
    let tripID: UUID
    let tripName: String

    private var folderName: String { Self.fileName("\(tripName) receipts") }
    var zipName: String { "\(folderName).zip" }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { SentTransferredFile(try await $0.zip()) }
    }

    @concurrent private func zip() async throws -> URL {
        let id = tripID
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.trip?.uuid == id }, sortBy: [SortDescriptor(\.date)])
        let entries = try ModelContext(container).fetch(descriptor)
        let workFolder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let folder = workFolder.appending(path: folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let receipts = entries.compactMap { entry in entry.receipt.map { (entry, $0) } }
        for (index, (entry, receipt)) in receipts.enumerated() {
            let date = entry.date.formatted(.iso8601.year().month().day())
            let name = "\(String(format: "%02d", index + 1)) \(date) \(entry.title) \(entry.typedAmount) \(entry.typedCode)"
            try receipt.write(to: folder.appending(path: "\(Self.fileName(name)).jpg"))
        }
        // iOS has no zip API, but a coordinated read with `.forUploading` gives a zip of a folder.
        var coordinationError: NSError?
        var zipped: Result<URL, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { temporaryZip in
            let zip = workFolder.appending(path: zipName)
            zipped = Result {
                try FileManager.default.copyItem(at: temporaryZip, to: zip)
                return zip
            }
        }
        if let coordinationError { throw coordinationError }
        return try zipped.get()
    }

    private static func fileName(_ text: String) -> String {
        text.replacing(/[\/:]/, with: "-")
    }
}
