import SwiftData
import SwiftUI

struct CurrentTripSync: ViewModifier {
    @Query private var trips: [Trip]
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshedAt = Date.now

    func body(content: Content) -> some View {
        let now = max(refreshedAt, .now)
        let nextBoundary = trips.boundaries(after: now).first
        content
            .environment(\.currentTripID, trips.current(at: now)?.persistentModelID)
            .task(id: [nextBoundary, refreshedAt]) {
                guard let nextBoundary else { return }
                try? await Task.sleep(for: .seconds(nextBoundary.timeIntervalSinceNow))
                if !Task.isCancelled { refreshedAt = .now }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active { refreshedAt = .now }
            }
    }
}
