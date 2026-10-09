import UIKit

enum Haptics {
    // A sheet dismisses right after these actions, so a `.sensoryFeedback` trigger on it would never fire.
    static func picked() { UISelectionFeedbackGenerator().selectionChanged() }
    static func saved() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func deleted() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}
