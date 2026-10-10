import SwiftUI

struct DateField: View {
    @Binding var date: Date
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(Palette.pencil)
                label
                    .font(.body.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background { SketchyBackground(seed: 47, cornerRadius: 10) }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Date")
        .accessibilityValue(date.formatted(date: .complete, time: .omitted))
        .sheet(isPresented: $isPicking) {
            MonthCalendar(month: date, selection: date) { day in
                let calendar = Calendar.current
                let time = calendar.dateComponents([.hour, .minute, .second], from: date)
                date =
                    calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
            }
        }
    }

    private var label: Text {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return Text("Today") }
        if calendar.isDateInYesterday(date) { return Text("Yesterday") }
        if calendar.isDateInTomorrow(date) { return Text("Tomorrow") }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return Text(date.formatted(.dateTime.month(.abbreviated).day()))
        }
        return Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
    }
}
