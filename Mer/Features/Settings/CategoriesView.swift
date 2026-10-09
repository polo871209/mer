import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]
    @Environment(\.modelContext) private var context
    @State private var editing: EntryCategory?
    @State private var addingKind: EntryKind?

    var body: some View {
        List {
            ForEach(EntryKind.allCases) { kind in
                let items = categories.filter { $0.kind == kind }
                Section {
                    ForEach(items) { category in
                        Button {
                            editing = category
                        } label: {
                            HStack(spacing: 12) {
                                CategoryBadge(symbol: category.symbol, crayon: category.crayon, size: 34)
                                Text(category.name).foregroundStyle(Palette.ink)
                                Spacer()
                                Text(entryCount(category), format: .number)
                                    .foregroundStyle(Palette.pencil)
                            }
                        }
                        .swipeToDelete { context.delete(category) }
                    }
                    .onMove { source, destination in
                        var reordered = items
                        reordered.move(fromOffsets: source, toOffset: destination)
                        for (index, category) in reordered.enumerated() { category.sortOrder = index }
                    }
                    Button("Add Category", systemImage: "plus") { addingKind = kind }
                } header: {
                    Text(kind.title)
                } footer: {
                    if kind == .income {
                        Text(Self.deletionNote)
                    }
                }
            }
        }
        .paperBackground()
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
        }
        .sheet(item: $addingKind) { CategoryEditor(category: nil, kind: $0, nextSortOrder: nextSortOrder) }
        .sheet(item: $editing) { CategoryEditor(category: $0, kind: $0.kind, nextSortOrder: nextSortOrder) }
    }

    static let deletionNote: LocalizedStringKey = "Deleting a category keeps its entries. They show as Uncategorized."

    private var nextSortOrder: Int { (categories.map(\.sortOrder).max() ?? -1) + 1 }

    private func entryCount(_ category: EntryCategory) -> Int {
        let id = category.uuid
        return (try? context.fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.category?.uuid == id }))) ?? 0
    }
}

private struct CategoryEditor: View {
    private let category: EntryCategory?
    private let nextSortOrder: Int
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var symbol: String
    @State private var crayon: Crayon
    @State private var kind: EntryKind

    private static let symbols = [
        "fork.knife", "cup.and.saucer", "cart", "bag", "tram", "car", "fuelpump", "airplane",
        "house", "bolt", "drop", "wifi", "phone", "tv", "gamecontroller", "film",
        "music.note", "book", "graduationcap", "cross.case", "pills", "dumbbell", "pawprint", "gift",
        "heart", "tshirt", "scissors", "wrench.and.screwdriver", "banknote", "briefcase", "creditcard", "chart.line.uptrend.xyaxis", "sparkles",
    ]

    init(category: EntryCategory?, kind: EntryKind, nextSortOrder: Int) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "sparkles")
        _crayon = State(initialValue: category?.crayon ?? .butter)
        _kind = State(initialValue: kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        CategoryBadge(symbol: symbol, crayon: crayon, size: 80)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                    if category == nil {
                        Picker("Type", selection: $kind) {
                            ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("Crayon") {
                    HStack {
                        ForEach(Crayon.allCases) { option in
                            Button {
                                crayon = option
                            } label: {
                                CrayonFill(color: option.color, shape: SketchyEllipse(seed: 50), seed: 50)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        SketchyEllipse(seed: 50)
                                            .stroke(Palette.ink, lineWidth: option == crayon ? 3 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(option == crayon ? .isSelected : [])
                        }
                    }
                }
                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(Self.symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background {
                                        if option == symbol { SketchyEllipse(seed: 60).stroke(Palette.ink, lineWidth: 2) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .foregroundStyle(Palette.ink)
            .paperBackground()
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: symbol)
            .sensoryFeedback(.selection, trigger: crayon)
            .editorToolbar(
                canSave: !trimmedName.isEmpty,
                save: save,
                deletion: category.map { category in
                    EditorDeletion(
                        question: "Delete this category?",
                        confirmTitle: "Delete Category",
                        message: CategoriesView.deletionNote
                    ) { context.delete(category) }
                }
            )
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        if let category {
            category.name = trimmedName
            category.symbol = symbol
            category.crayon = crayon
        } else {
            context.insert(EntryCategory(name: trimmedName, symbol: symbol, crayon: crayon, kind: kind, sortOrder: nextSortOrder))
        }
    }
}

#Preview {
    NavigationStack { CategoriesView() }
        .modelContainer(Store.preview)
}
