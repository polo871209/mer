import LocalAuthentication
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.otherCurrencies) private var otherCurrencies = ""
    @AppStorage(DefaultsKey.lockEnabled) private var lockEnabled = false
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false
    @AppStorage(DefaultsKey.budgetEnabled) private var budgetEnabled = false
    @AppStorage(DefaultsKey.monthlyBudget) private var monthlyBudget = 0.0
    @Query(Self.firstEntry) private var entries: [Entry]
    @State private var canAuthenticate = false
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @Environment(\.modelContext) private var context

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
                    NavigationLink {
                        BudgetView()
                    } label: {
                        LabeledContent("Budget", value: budgetSummary)
                    }
                    NavigationLink("Categories") { CategoriesView() }
                    NavigationLink("Trips") { TripsView() }
                }

                Section("Layout") {
                    Picker("Add button", selection: $addButtonOnLeft) {
                        Text("Right").tag(false)
                        Text("Left").tag(true)
                    }
                }

                Section("Privacy") {
                    Toggle("Lock with Face ID", isOn: $lockEnabled)
                        .disabled(!lockEnabled && !canAuthenticate)
                    Link("Privacy Policy", destination: URL(string: "https://polo871209.github.io/mer/privacy/")!)
                }

                Section("Data") {
                    Button("Import CSV", systemImage: "square.and.arrow.down") { isImporting = true }
                    ShareLink(item: EntriesCSV(), preview: SharePreview("Mer entries.csv")) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .paperBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText]) { result in
                importResult = ImportResult(importing: result, into: context)
                if case .success(let summary) = importResult?.outcome {
                    var accounts = Accounts(main: mainCurrency, storedOthers: otherCurrencies)
                    for code in summary.accountCodes.sorted() { accounts = accounts.adding(code) }
                    otherCurrencies = accounts.storedOthers
                    Haptics.saved()
                }
            }
            .alert(importResult?.title ?? "", item: $importResult) { _ in
            } message: { result in
                Text(result.message)
            }
        }
        .task { canAuthenticate = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }
    }

    private var budgetSummary: String {
        MonthlyBudget.limit(isOn: budgetEnabled, stored: monthlyBudget)?.money(mainCurrency) ?? String(localized: "Off")
    }
}

private struct ImportResult {
    let outcome: Result<ImportSummary, any Error>

    init(importing file: Result<URL, any Error>, into context: ModelContext) {
        outcome = Result {
            let url = try file.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            return try EntriesImport.run(String(contentsOf: url, encoding: .utf8), into: context)
        }
    }

    var title: String {
        switch outcome {
        case .success: String(localized: "Import Done")
        case .failure: String(localized: "Import Failed")
        }
    }

    var message: String {
        switch outcome {
        case .success(let summary):
            var lines = [String(localized: "Added \(summary.added) entries.")]
            if summary.duplicates > 0 {
                lines.append(String(localized: "Skipped \(summary.duplicates) entries that Mer already has."))
            }
            if let first = summary.invalidLines.first {
                lines.append(String(localized: "Skipped \(summary.invalidLines.count) rows that Mer cannot read. The first is on line \(first)."))
            }
            return lines.joined(separator: "\n")
        case .failure(let error):
            return error.localizedDescription
        }
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
        var descriptor = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.category, \.trip]
        let entries = try Store.shared.mainContext.fetch(descriptor)
        let header = ["Date", "Type", "Category", "Amount", "Account", "Original Amount", "Original Currency", "Trip", "Note"]
        let rows = entries.map { entry in
            [
                entry.date.formatted(.iso8601),
                entry.kind.rawValue,
                entry.category?.name ?? "",
                entry.amount.description,
                entry.accountCode,
                entry.originalAmount?.description ?? "",
                entry.originalCode ?? "",
                entry.trip?.name ?? "",
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
