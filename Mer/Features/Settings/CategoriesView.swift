import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Query(sort: \EntryCategory.sortOrder) private var categories: [EntryCategory]
    @Environment(\.modelContext) private var context
    @State private var editing: EntryCategory?
    @State private var isAdding = false

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
                                Text(category.entries?.count ?? 0, format: .number)
                                    .foregroundStyle(Palette.pencil)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(items[index]) }
                    }
                    .onMove { source, destination in
                        var reordered = items
                        reordered.move(fromOffsets: source, toOffset: destination)
                        for (index, category) in reordered.enumerated() { category.sortOrder = index }
                    }
                } header: {
                    Text(kind.title)
                } footer: {
                    if kind == .income {
                        Text("Deleting a category keeps its entries. They show as Uncategorized.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { PaperBackground() }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Category", systemImage: "plus") { isAdding = true }
            }
        }
        .sheet(isPresented: $isAdding) { CategoryEditor(category: nil, nextSortOrder: categories.count) }
        .sheet(item: $editing) { CategoryEditor(category: $0, nextSortOrder: categories.count) }
    }
}

private struct CategoryEditor: View {
    private let category: EntryCategory?
    private let nextSortOrder: Int
    @Environment(\.dismiss) private var dismiss
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

    init(category: EntryCategory?, nextSortOrder: Int) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "sparkles")
        _crayon = State(initialValue: category?.crayon ?? .butter)
        _kind = State(initialValue: category?.kind ?? .expense)
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
                            .accessibilityLabel(option)
                            .accessibilityAddTraits(option == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .foregroundStyle(Palette.ink)
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: symbol)
            .sensoryFeedback(.selection, trigger: crayon)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", role: .confirm) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            category.name = trimmed
            category.symbol = symbol
            category.crayon = crayon
        } else {
            context.insert(EntryCategory(name: trimmed, symbol: symbol, crayon: crayon, kind: kind, sortOrder: nextSortOrder))
        }
        dismiss()
    }
}

#Preview {
    NavigationStack { CategoriesView() }
        .modelContainer(Store.preview)
}
