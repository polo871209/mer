import SwiftUI

struct BudgetDetail: View {
    let budget: BudgetProgress
    @Environment(\.currencyCode) private var code

    var body: some View {
        BudgetBar(budget: budget)
        Group {
            if budget.isOver {
                Text("Budget \(budget.limit.money(code))")
            } else {
                Text("\(budget.left.money(code)) left of \(budget.limit.money(code))")
            }
        }
        .font(.crayon(14, relativeTo: .subheadline, bold: false))
        .foregroundStyle(Palette.pencil)
    }
}

private struct BudgetBar: View {
    let budget: BudgetProgress

    var body: some View {
        let outline = SketchyRect(cornerRadius: 7, wobble: 1, seed: 41)
        CrayonFill(color: budget.level.barColor, shape: outline, seed: 41)
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: min(budget.share, 1), anchor: .leading)
            }
            .overlay { outline.stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)) }
            .overlay(alignment: .leading) {
                if let limitShare = budget.limitShare {
                    Capsule()
                        .fill(Palette.ink)
                        .frame(width: 3, height: 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .visualEffect { content, proxy in
                            content.offset(x: proxy.size.width * limitShare - 1.5)
                        }
                }
            }
            .frame(height: 16)
            .accessibilityHidden(true)
    }
}

extension BudgetLevel {
    var barColor: Color {
        switch self {
        case .under: Crayon.sage.color
        case .near: Crayon.butter.color
        case .reached: Palette.expense
        }
    }

    var textColor: Color {
        switch self {
        case .under: Palette.ink
        case .near: Palette.warning
        case .reached: Palette.expense
        }
    }
}
