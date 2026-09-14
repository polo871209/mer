import SwiftUI
import UIKit

nonisolated enum Palette {
    static let inkUIColor = UIColor(light: 0x2B2521, dark: 0xF1E9DA)

    static let paper = Color(light: 0xF7F1E3, dark: 0x221E1B)
    static let card = Color(light: 0xFFFBF2, dark: 0x2D2824)
    static let highlight = Color(light: 0xF6E5B8, dark: 0x574825)
    static let ink = Color(uiColor: inkUIColor)
    static let pencil = Color(light: 0x7A6C60, dark: 0xB5A897)
    static let income = Color(light: 0x3F7F3B, dark: 0xA5D49E)
    static let expense = Color(light: 0xB8444F, dark: 0xF0A0AB)
}

nonisolated enum Crayon: String, CaseIterable, Identifiable {
    case butter, blush, sky, fur, sage, cocoa, lilac, tangerine

    var id: Self { self }

    var color: Color {
        switch self {
        case .butter: Color(light: 0xF2C54B, dark: 0xE0B43E)
        case .blush: Color(light: 0xEE98A5, dark: 0xD9808E)
        case .sky: Color(light: 0x9CC4E8, dark: 0x7EA9D1)
        case .fur: Color(light: 0xD8B48A, dark: 0xC09A70)
        case .sage: Color(light: 0x9FCB98, dark: 0x86B57F)
        case .cocoa: Color(light: 0x9C7C64, dark: 0xA88A72)
        case .lilac: Color(light: 0xC3A8DE, dark: 0xA88CC7)
        case .tangerine: Color(light: 0xF4A261, dark: 0xE08C4A)
        }
    }
}

extension Font {
    static func crayon(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, bold: Bool = true) -> Font {
        .custom(bold ? "ChalkboardSE-Bold" : "ChalkboardSE-Regular", size: size, relativeTo: style)
    }
}

enum Theme {
    static func styleNavigationBars() {
        func chalkboard(_ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
            let base = UIFont(name: "ChalkboardSE-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
            return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: chalkboard(34, .largeTitle), .foregroundColor: Palette.inkUIColor]
        bar.titleTextAttributes = [.font: chalkboard(17, .headline), .foregroundColor: Palette.inkUIColor]
    }
}

nonisolated extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}

nonisolated extension UIColor {
    convenience init(light: UInt32, dark: UInt32) {
        self.init { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
