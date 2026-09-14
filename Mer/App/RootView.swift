import SwiftUI

enum AppTab: CaseIterable {
    case home, entries, settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .entries: "Entries"
        case .settings: "Settings"
        }
    }

    var icon: Image {
        switch self {
        case .home: Image(.homeTab)
        case .entries: Image(.entriesTab)
        case .settings: Image(.settingsTab)
        }
    }
}

struct RootView: View {
    @AppStorage(DefaultsKey.currencyCode) private var currencyCode = Money.defaultCode
    @State private var tab = AppTab.home
    @State private var isAdding = false

    var body: some View {
        // The system tab bar cannot hold a separate add button, so each tab hides it and `MerTabBar` draws the bar.
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                DashboardView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.entries) {
                EntriesView().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(value: AppTab.settings) {
                SettingsView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MerTabBar(selection: $tab) { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { EntryEditor(entry: nil) }
        .tint(Palette.ink)
        // `.fontDesign(.rounded)` would also override the Chalkboard custom fonts, so set a default font instead.
        .font(.system(.body, design: .rounded))
        .environment(\.currencyCode, currencyCode)
        .modifier(CloudSync())
        .modifier(AppLockModifier())
    }
}

private struct MerTabBar: View {
    @Binding var selection: AppTab
    let add: () -> Void
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false
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
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var addButton: some View {
        Button(action: add) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 62, height: 62)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Palette.highlight).interactive(), in: .circle)
        .accessibilityLabel("Add Entry")
    }
}
