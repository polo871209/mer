import SwiftUI

enum AppTab: CaseIterable {
    case home, report, settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .report: "Report"
        case .settings: "Settings"
        }
    }

    var icon: Image {
        switch self {
        case .home: Image(.homeTab)
        case .report: Image(.reportTab)
        case .settings: Image(.settingsTab)
        }
    }
}

struct RootView: View {
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @State private var tab = AppTab.home
    @State private var newEntry: NewEntryRequest?

    var body: some View {
        // The system tab bar cannot hold a separate add button, so each tab hides it and `MerTabBar` draws the bar.
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                DashboardView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.report) {
                ReportTab().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.settings) {
                SettingsView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MerTabBar(selection: $tab) { newEntry = NewEntryRequest(categoryID: nil) }
        }
        .sheet(item: $newEntry) { request in
            EntryEditor(.new(categoryID: request.categoryID)).id(request.id)
        }
        .onOpenURL { url in
            guard case .newEntry(let categoryID) = DeepLink(url) else { return }
            withTransaction(\.disablesAnimations, true) { newEntry = NewEntryRequest(categoryID: categoryID) }
        }
        .tint(Palette.ink)
        // `.fontDesign(.rounded)` would also override the Chalkboard custom fonts, so set a default font instead.
        .font(.system(.body, design: .rounded))
        .environment(\.currencyCode, mainCurrency)
        .task { await ExchangeRates.shared.refreshIfStale() }
        .modifier(CloudSync())
        .modifier(CurrentTripSync())
        .modifier(WidgetCategorySync())
        .modifier(AppLockModifier())
    }
}

private struct NewEntryRequest: Identifiable {
    let id = UUID()
    let categoryID: UUID?
}

private struct MerTabBar: View {
    @Binding var selection: AppTab
    let add: () -> Void
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false
    @Environment(\.currentTripID) private var currentTripID
    @Namespace private var highlight

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if addButtonOnLeft { addButton }
                tabs
                if !addButtonOnLeft { addButton }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, -6)
        .animation(.snappy, value: addButtonOnLeft)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(.snappy) { selection = item }
                } label: {
                    VStack(spacing: 3) {
                        item.icon
                            .frame(height: 26)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? Palette.ink : Palette.pencil)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Palette.ink.opacity(0.1))
                                .matchedGeometryEffect(id: "selected", in: highlight)
                        }
                    }
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityShowsLargeContentViewer()
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var addButton: some View {
        let isOnTrip = currentTripID != nil
        return Button(action: add) {
            Image(systemName: isOnTrip ? "suitcase.rolling.fill" : "plus")
                .font(.system(size: isOnTrip ? 18 : 24, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 62, height: 62)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(isOnTrip ? Crayon.sky.color : Palette.highlight).interactive(), in: .circle)
        .animation(.snappy, value: isOnTrip)
        .accessibilityLabel(isOnTrip ? "Add Trip Entry" : "Add Entry")
    }
}
