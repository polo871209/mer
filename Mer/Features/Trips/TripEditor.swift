import SwiftData
import SwiftUI

struct TripEditor: View {
    private let trip: Trip?
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var isClaimable: Bool
    @State private var start: Date?
    @State private var end: Date?
    @State private var currencyCode: String?
    @State private var isPickingCurrency = false
    private let calendar = Calendar.current

    init(trip: Trip?) {
        self.trip = trip
        _name = State(initialValue: trip?.name ?? "")
        _isClaimable = State(initialValue: trip?.isClaimable ?? true)
        _start = State(initialValue: trip?.start)
        _end = State(initialValue: trip?.end)
        _currencyCode = State(initialValue: trip?.currencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Toggle("Claimable", isOn: $isClaimable)
                } footer: {
                    Text("A claimable trip shows what is left to claim back.")
                }
                Section {
                    Button {
                        isPickingCurrency = true
                    } label: {
                        LabeledContent("Currency", value: Money.name(currencyCode ?? Money.mainCode))
                            .foregroundStyle(Palette.ink)
                    }
                    .sheet(isPresented: $isPickingCurrency) {
                        CurrencyPicker(selection: currencyCode ?? Money.mainCode) {
                            currencyCode = $0 == Money.mainCode ? nil : $0
                        }
                    }
                } footer: {
                    Text("New entries on this trip start in this currency.")
                }
                Section {
                    Toggle("Start date", isOn: hasStart)
                    if start != nil {
                        LabeledContent("Starts") { DateField(date: startDay) }
                    }
                    Toggle("End date", isOn: hasEnd)
                    if end != nil {
                        LabeledContent("Ends") { DateField(date: endDay) }
                    }
                } header: {
                    Text("Trip mode")
                } footer: {
                    Text("Trip mode turns on at the start date and off after the end date. Entries on any date can join the trip.")
                }
                if let trip, trip.hasReceipts {
                    Section {
                        ReceiptsShareLink(trip: trip)
                    } footer: {
                        Text("Shares every receipt on this trip as one zip file.")
                    }
                }
            }
            .foregroundStyle(Palette.ink)
            .paperBackground()
            .navigationTitle(trip == nil ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.snappy, value: start == nil)
            .animation(.snappy, value: end == nil)
            .editorToolbar(canSave: !trimmedName.isEmpty && datesAreInOrder, save: save)
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var datesAreInOrder: Bool {
        guard let start, let end else { return true }
        return start < end
    }

    private var hasStart: Binding<Bool> {
        Binding {
            start != nil
        } set: {
            start = $0 ? calendar.startOfDay(for: .now) : nil
        }
    }

    private var hasEnd: Binding<Bool> {
        Binding {
            end != nil
        } set: {
            end = $0 ? dayAfter(max(start ?? .now, .now)) : nil
        }
    }

    private var startDay: Binding<Date> {
        Binding {
            start ?? .now
        } set: {
            start = calendar.startOfDay(for: $0)
        }
    }

    private var endDay: Binding<Date> {
        Binding {
            (end ?? .now).addingTimeInterval(-1)
        } set: {
            end = dayAfter($0)
        }
    }

    private func dayAfter(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }

    private func save() {
        let target = trip ?? Trip(name: trimmedName)
        if trip == nil { context.insert(target) }
        target.name = trimmedName
        target.isClaimable = isClaimable
        target.start = start
        target.end = end
        target.currencyCode = currencyCode
        try? context.save()
    }
}

#Preview {
    TripEditor(trip: nil)
        .modelContainer(Store.preview)
}
