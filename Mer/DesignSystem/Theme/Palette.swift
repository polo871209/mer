import SwiftUI

enum Palette {
    static let paper = Color(.paper)
    static let card = Color(.card)
    static let highlight = Color(.highlight)
    static let ink = Color(.ink)
    static let pencil = Color(.pencil)
    static let income = Color(.income)
    static let expense = Color(.expense)
    static let warning = Color(.warning)
    static let balance = Color(.balance)
}

nonisolated enum Crayon: String, CaseIterable, Identifiable, Codable {
    case butter, blush, sky, fur, sage, cocoa, lilac, tangerine

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .butter: "Butter"
        case .blush: "Blush"
        case .sky: "Sky"
        case .fur: "Fur"
        case .sage: "Sage"
        case .cocoa: "Cocoa"
        case .lilac: "Lilac"
        case .tangerine: "Tangerine"
        }
    }

    @MainActor var color: Color {
        switch self {
        case .butter: Color(.crayonButter)
        case .blush: Color(.crayonBlush)
        case .sky: Color(.crayonSky)
        case .fur: Color(.crayonFur)
        case .sage: Color(.crayonSage)
        case .cocoa: Color(.crayonCocoa)
        case .lilac: Color(.crayonLilac)
        case .tangerine: Color(.crayonTangerine)
        }
    }
}

extension Font {
    static func crayon(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = true) -> Font {
        .custom(bold ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular", size: size, relativeTo: style)
    }
}

extension Text {
    func cardTitle() -> some View {
        font(.crayon(20, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
    }
}

enum Theme {
    static func styleNavigationBars() {
        func chalkboard(_ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
            let base = UIFont(name: "ChalkboardSE-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        }
        let ink = UIColor(resource: .ink)
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: chalkboard(34, .largeTitle), .foregroundColor: ink]
        bar.titleTextAttributes = [.font: chalkboard(17, .headline), .foregroundColor: ink]
    }
}
