import SwiftUI

extension View {
    func followsCurrentPeriod(_ date: Binding<Date>, period: Period) -> some View {
        modifier(FollowsCurrentPeriod(date: date, period: period))
    }
}

private struct FollowsCurrentPeriod: ViewModifier {
    @Binding var date: Date
    let period: Period
    @State private var lastSeen = Date.now

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            let wasCurrent = period.interval(containing: lastSeen).contains(date)
            lastSeen = .now
            if wasCurrent, !period.interval(containing: .now).contains(date) {
                date = .now
            }
        }
    }
}
