import AppIntents
import SwiftUI
import WidgetKit

@main
struct CategoryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Categories", intent: CategoryWidgetConfiguration.self, provider: CategoryProvider()) {
            CategoryWidgetView(categories: $0.categories)
        }
        .configurationDisplayName("Quick Add")
        .description("Tap a category to type the amount.")
        .supportedFamilies([.systemSmall])
    }
}

struct CategoryWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Categories"
    static let description = IntentDescription("Pick the four categories that the widget shows.")

    @Parameter(title: "Categories", size: 4)
    var categories: [CategoryShortcut]?
}

nonisolated extension CategoryShortcut: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let defaultQuery = CategoryShortcutQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

nonisolated struct CategoryShortcutQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CategoryShortcut] {
        CategoryShortcut.all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CategoryShortcut] {
        CategoryShortcut.all
    }
}

private nonisolated struct CategoryEntry: TimelineEntry {
    let date = Date.now
    let categories: [CategoryShortcut]

    init(picked: [CategoryShortcut]) {
        let all = CategoryShortcut.all
        let current = picked.compactMap { pick in all.first { $0.id == pick.id } }
        categories = Array((current + all.filter { !current.contains($0) }).prefix(4))
    }
}

private nonisolated struct CategoryProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CategoryEntry { CategoryEntry(picked: []) }

    func snapshot(for configuration: CategoryWidgetConfiguration, in context: Context) async -> CategoryEntry {
        CategoryEntry(picked: configuration.categories ?? [])
    }

    func timeline(for configuration: CategoryWidgetConfiguration, in context: Context) async -> Timeline<CategoryEntry> {
        Timeline(entries: [CategoryEntry(picked: configuration.categories ?? [])], policy: .never)
    }
}

private struct CategoryWidgetView: View {
    let categories: [CategoryShortcut]

    var body: some View {
        Group {
            if categories.isEmpty {
                Text("Open Mer once to load your categories.")
                    .font(.crayon(15, relativeTo: .subheadline, bold: false))
                    .multilineTextAlignment(.center)
                    .widgetURL(DeepLink.newEntry(categoryID: nil).url)
            } else {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach([0, 2], id: \.self) { start in
                        GridRow {
                            ForEach(categories.dropFirst(start).prefix(2)) { category in
                                Link(destination: DeepLink.newEntry(categoryID: category.id).url) {
                                    CategoryBadge(symbol: category.symbol, crayon: category.crayon, size: 58)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .accessibilityLabel(category.name)
                            }
                        }
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(for: .widget) { PaperBackground() }
    }
}
