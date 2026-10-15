import AppIntents
import SwiftUI
import WidgetKit

@main
struct CategoryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Categories", intent: CategoryWidgetConfiguration.self, provider: CategoryProvider()) {
            CategoryWidgetView(entry: $0)
                .environment(\.colorScheme, .light)
        }
        .configurationDisplayName("Quick Add")
        .description("Tap a category to type the amount. The medium size also shows your spending this month.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
    let date: Date
    let categories: [CategoryShortcut]
    let budget = BudgetSnapshot.stored

    init(date: Date = .now, picked: [CategoryShortcut]) {
        self.date = date
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
        let picked = configuration.categories ?? []
        let nextMonth = Period.month.interval(containing: .now).end
        return Timeline(entries: [CategoryEntry(picked: picked), CategoryEntry(date: nextMonth, picked: picked)], policy: .never)
    }
}

private struct CategoryWidgetView: View {
    let entry: CategoryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.categories.isEmpty {
                Text("Open Mer once to load your categories.")
                    .font(.crayon(15, relativeTo: .subheadline, bold: false))
                    .multilineTextAlignment(.center)
                    .widgetURL(DeepLink.newEntry(categoryID: nil).url)
            } else {
                HStack(spacing: 16) {
                    CategoryGrid(categories: entry.categories)
                    if family == .systemMedium {
                        BudgetRing(snapshot: entry.budget, date: entry.date)
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(for: .widget) { PaperBackground().environment(\.colorScheme, .light) }
    }
}

private struct CategoryGrid: View {
    let categories: [CategoryShortcut]

    var body: some View {
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
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct BudgetRing: View {
    let snapshot: BudgetSnapshot?
    let date: Date

    var body: some View {
        if let snapshot {
            let budget = snapshot.limit.map { BudgetProgress(limit: $0, spent: snapshot.spent(on: date)) }
            VStack(spacing: 6) {
                ZStack {
                    if let budget {
                        let used = Circle().inset(by: 6).trim(from: 0, to: min(budget.share, 1)).stroke(lineWidth: 12).rotation(.degrees(-90))
                        CrayonFill(color: budget.level.barColor, shape: used, seed: 41)
                        SketchyEllipse(seed: 41).stroke(Palette.ink, lineWidth: 1.6)
                        SketchyEllipse(seed: 42).stroke(Palette.ink, lineWidth: 1.6).padding(12)
                    }
                    MerAvatar(size: 52)
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(budget.map { Text("\($0.share, format: .percent.precision(.fractionLength(0))) of the budget used") } ?? Text(""))
                Text(budget?.hint ?? "No budget set")
                    .font(.crayon(15, relativeTo: .subheadline))
                    .foregroundStyle(budget?.level.textColor ?? Palette.pencil)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .privacySensitive()
        } else {
            Text("Open Mer once to load your budget.")
                .font(.crayon(15, relativeTo: .subheadline, bold: false))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

extension BudgetProgress {
    fileprivate var hint: LocalizedStringResource {
        if isOver { return "Over budget" }
        switch level {
        case .under: return "On track"
        case .near: return "Almost at budget"
        case .reached: return "Budget used up"
        }
    }
}
