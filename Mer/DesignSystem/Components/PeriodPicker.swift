import SwiftUI

struct PeriodPicker: View {
    let period: Period
    @Binding var date: Date
    var allowsFuture = false
    var titleAction: (() -> Void)?

    var body: some View {
        HStack {
            Button(period.previousTitle, systemImage: "chevron.left") {
                shift(by: -1)
            }
            Spacer()
            if let titleAction {
                Button(action: titleAction) {
                    HStack(spacing: 6) {
                        title
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.pencil)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows a calendar")
            } else {
                title
            }
            Spacer()
            Button(period.nextTitle, systemImage: "chevron.right") {
                shift(by: 1)
            }
            .disabled(!allowsFuture && Calendar.current.isDate(date, equalTo: .now, toGranularity: period.unit))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .sensoryFeedback(.selection, trigger: date)
    }

    private var title: some View {
        Text(period.label(for: date))
            .font(.crayon(20, relativeTo: .title3))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }

    private func shift(by count: Int) {
        withAnimation(.snappy) {
            date = Calendar.current.date(byAdding: period.unit, value: count, to: date) ?? date
        }
    }
}

extension Period {
    fileprivate var previousTitle: LocalizedStringKey {
        switch self {
        case .month: "Previous Month"
        case .year: "Previous Year"
        }
    }

    fileprivate var nextTitle: LocalizedStringKey {
        switch self {
        case .month: "Next Month"
        case .year: "Next Year"
        }
    }
}
