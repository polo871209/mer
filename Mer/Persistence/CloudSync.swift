import Combine
import Foundation
import SwiftData
import SwiftUI

struct CloudSync: ViewModifier {
    @Query private var categories: [EntryCategory]
    @Environment(\.modelContext) private var context
    @AppStorage(DefaultsKey.currencyCode) private var currencyCode = Money.defaultCode
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false

    func body(content: Content) -> some View {
        content
            .onChange(of: categories.count, initial: true) {
                Store.mergeDuplicateCategories(in: context)
            }
            .onAppear {
                NSUbiquitousKeyValueStore.default.synchronize()
                pullSettings()
            }
            // The store posts this notification on a background queue.
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
                    .receive(on: DispatchQueue.main)
            ) { _ in
                pullSettings()
            }
            .onChange(of: currencyCode) {
                NSUbiquitousKeyValueStore.default.set(currencyCode, forKey: DefaultsKey.currencyCode)
            }
            .onChange(of: addButtonOnLeft) {
                NSUbiquitousKeyValueStore.default.set(addButtonOnLeft, forKey: DefaultsKey.addButtonOnLeft)
            }
    }

    private func pullSettings() {
        let cloud = NSUbiquitousKeyValueStore.default
        if let code = cloud.string(forKey: DefaultsKey.currencyCode) {
            currencyCode = code
        }
        if cloud.object(forKey: DefaultsKey.addButtonOnLeft) != nil {
            addButtonOnLeft = cloud.bool(forKey: DefaultsKey.addButtonOnLeft)
        }
    }
}
