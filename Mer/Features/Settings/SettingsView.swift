import LocalAuthentication
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.lockEnabled) private var lockEnabled = false
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false
    @Query(Self.firstEntry) private var entries: [Entry]
    @State private var canAuthenticate = false

    private static var firstEntry: FetchDescriptor<Entry> {
        var descriptor = FetchDescriptor<Entry>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        MerAvatar(size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mer").font(.crayon(24, relativeTo: .title2))
                            Text("It's Mer's money. You just carry it.").foregroundStyle(Palette.pencil)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Money") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        LabeledContent("Accounts", value: Money.name(mainCurrency))
                    }
                    NavigationLink("Categories") { CategoriesView() }
                }

                Section {
                    Picker("Add button", selection: $addButtonOnLeft) {
                        Text("Right").tag(false)
                        Text("Left").tag(true)
                    }
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Put the + button on the side your thumb reaches.")
                }

                Section {
                    Toggle("Lock with Face ID", isOn: $lockEnabled)
                        .disabled(!lockEnabled && !canAuthenticate)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Mer covers your numbers in the app switcher and asks for Face ID when you come back.")
                }

                Section("Data") {
                    ShareLink(item: EntriesCSV(), preview: SharePreview("Mer entries.csv")) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .paperBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .task { canAuthenticate = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }
    }
}

nonisolated struct EntriesCSV: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { _ in
            let csv = try await MainActor.run { try text() }
            return Data(csv.utf8)
        }
        .suggestedFileName("Mer entries.csv")
    }

    @MainActor
    private static func text() throws -> String {
        let entries = try Store.shared.mainContext.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let header = ["Date", "Type", "Category", "Amount", "Account", "Original Amount", "Original Currency", "Note"]
        let rows = entries.map { entry in
            [
                entry.date.formatted(.iso8601),
                entry.kind.rawValue,
                entry.category?.name ?? "",
                entry.amount.description,
                entry.accountCode,
                entry.originalAmount?.description ?? "",
                entry.originalCode ?? "",
                entry.note,
            ]
        }
        return CSV.make([header] + rows)
    }
}

#Preview {
    SettingsView()
        .modelContainer(Store.preview)
}
