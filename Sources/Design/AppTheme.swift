import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppTheme {
    let accent = Color(red: 0.10, green: 0.47, blue: 0.32)
    let accentDark = Color(red: 0.055, green: 0.25, blue: 0.17)
    /// Preserve the warm ivory canvas from the first native SwiftUI version instead of letting
    /// system containers fall back to a pure-white page in light appearance.
    let canvas = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .systemGroupedBackground
        }
        return UIColor(red: 0.965, green: 0.955, blue: 0.91, alpha: 1)
    })
    let surface = Color(uiColor: .secondarySystemGroupedBackground)
    let surfaceMuted = Color(uiColor: .tertiarySystemGroupedBackground)
    let ink = Color.primary
    let secondaryInk = Color.secondary
}

extension Color {
    /// Dark emphasis colors for surfaces that carry white text. These intentionally remain
    /// dark in both appearances so every risk-level hero keeps sufficient contrast.
    static let riskUnratedProminent = Color(red: 0.24, green: 0.27, blue: 0.26)
    static let riskHighProminent = Color(red: 0.46, green: 0.05, blue: 0.08)
    static let riskModerateProminent = Color(red: 0.43, green: 0.23, blue: 0.02)
    static let riskLowProminent = Color(red: 0.055, green: 0.25, blue: 0.17)

    static let riskUnrated = adaptiveColor(
        light: UIColor(red: 0.30, green: 0.33, blue: 0.32, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.75, blue: 0.74, alpha: 1)
    )
    static let riskHigh = adaptiveColor(
        light: UIColor(red: 0.70, green: 0.08, blue: 0.12, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.42, blue: 0.45, alpha: 1)
    )
    static let riskModerate = adaptiveColor(
        light: UIColor(red: 0.58, green: 0.31, blue: 0.00, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.70, blue: 0.28, alpha: 1)
    )
    static let riskLow = adaptiveColor(
        light: UIColor(red: 0.04, green: 0.39, blue: 0.21, alpha: 1),
        dark: UIColor(red: 0.37, green: 0.85, blue: 0.58, alpha: 1)
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
