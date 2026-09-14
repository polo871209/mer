import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(DefaultsKey.currencyCode) private var currencyCode = Money.defaultCode
    @AppStorage(DefaultsKey.lockEnabled) private var lockEnabled = false
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        MerAvatar(size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mer").font(.crayon(24, relativeTo: .title2))
                            Text("Your money, counted by a cat.").foregroundStyle(Palette.pencil)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Money") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                            Text(verbatim: "\(Locale.current.localizedString(forCurrencyCode: code) ?? code) (\(code))").tag(code)
                        }
                    }
                    .pickerStyle(.navigationLink)
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
                        .disabled(!lockEnabled && !AppLock.canAuthenticate)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Mer covers your numbers in the app switcher and asks for Face ID when you come back.")
                }

                Section("Data") {
                    ShareLink(item: CSVDocument(entries: entries), preview: SharePreview("Mer entries.csv")) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    LabeledContent("Entries", value: entries.count, format: .number)
                }
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
}

nonisolated struct CSVDocument: Transferable {
    let text: String

    @MainActor init(entries: [Entry]) {
        let code = Money.currentCode
        let header = ["Date", "Type", "Category", "Amount", "Currency", "Note"]
        let rows = entries.map { entry in
            [
                entry.date.formatted(.iso8601),
                entry.kind.rawValue,
                entry.category?.name ?? "",
                entry.amount.plainString,
                code,
                entry.note,
            ]
        }
        text = CSV.make([header] + rows)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let url = URL.temporaryDirectory.appending(path: "Mer entries.csv")
            try document.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(Store.preview)
}
