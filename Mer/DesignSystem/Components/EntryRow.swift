import SwiftUI

struct EntryRow: View {
    let entry: Entry
    @Environment(\.currencyCode) private var code

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(symbol: entry.category?.symbol ?? "questionmark", crayon: entry.category?.crayon ?? .cocoa)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.pencil)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(entry.signedAmount.signedMoney(code))
                .font(.crayon(17, relativeTo: .body))
                .foregroundStyle(entry.kind == .income ? Palette.income : Palette.ink)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let date = entry.date.formatted(.dateTime.month(.abbreviated).day())
        guard !entry.note.isEmpty, let name = entry.category?.name else { return date }
        return "\(name) · \(date)"
    }
}
