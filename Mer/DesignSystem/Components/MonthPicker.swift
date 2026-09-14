import SwiftUI

struct MonthPicker: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") { shift(by: -1) }
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.crayon(20, relativeTo: .title3))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button("Next Month", systemImage: "chevron.right") { shift(by: 1) }
                .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .sensoryFeedback(.selection, trigger: month)
    }

    private func shift(by months: Int) {
        withAnimation(.snappy) {
            month = Calendar.current.date(byAdding: .month, value: months, to: month) ?? month
        }
    }
}
