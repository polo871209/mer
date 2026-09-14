import SwiftData
import SwiftUI

@main
struct MerApp: App {
    init() {
        Theme.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Store.shared)
    }
}
