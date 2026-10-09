import Foundation
import SwiftData
import SwiftUI

struct CloudSync: ViewModifier {
    @Query(filter: #Predicate<EntryCategory> { $0.seedKey != nil }) private var seededCategories: [EntryCategory]
    @Environment(\.modelContext) private var context
    @AppStorage(DefaultsKey.mainCurrency) private var mainCurrency = Money.defaultCode
    @AppStorage(DefaultsKey.otherCurrencies) private var otherCurrencies = ""
    @AppStorage(DefaultsKey.addButtonOnLeft) private var addButtonOnLeft = false

    func body(content: Content) -> some View {
        content
            .onChange(of: seededCategories.count, initial: true) {
                Store.mergeDuplicateCategories(in: context)
            }
            .task {
                NSUbiquitousKeyValueStore.default.synchronize()
                pullSettings()
                for await _ in NotificationCenter.default.notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
                    pullSettings()
                }
            }
            .onChange(of: mainCurrency) {
                NSUbiquitousKeyValueStore.default.set(mainCurrency, forKey: DefaultsKey.mainCurrency)
            }
            .onChange(of: otherCurrencies) {
                NSUbiquitousKeyValueStore.default.set(otherCurrencies, forKey: DefaultsKey.otherCurrencies)
            }
            .onChange(of: addButtonOnLeft) {
                NSUbiquitousKeyValueStore.default.set(addButtonOnLeft, forKey: DefaultsKey.addButtonOnLeft)
            }
    }

    private func pullSettings() {
        let cloud = NSUbiquitousKeyValueStore.default
        if let code = cloud.string(forKey: DefaultsKey.mainCurrency) {
            mainCurrency = code
        }
        if let codes = cloud.string(forKey: DefaultsKey.otherCurrencies) {
            otherCurrencies = codes
        }
        if cloud.object(forKey: DefaultsKey.addButtonOnLeft) != nil {
            addButtonOnLeft = cloud.bool(forKey: DefaultsKey.addButtonOnLeft)
        }
    }
}
