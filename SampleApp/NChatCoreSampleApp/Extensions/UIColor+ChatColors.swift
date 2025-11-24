import UIKit

public extension UIColor {

    // MARK: Content
    // Text, icons and borders of elements
    enum Content {
        // Black in light mode, white in dark mode
        public static let high = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .white : .black
        }
        // Dark Gray
        public static let mid = UIColor(red: 153/255, green: 153/255, blue: 153/255, alpha: 1.0)
    }

    // MARK: Background
    // View backgrounds, sections, big independent surfaces and overlays
    enum Background {
        // White
        public static let base = UIColor.white
    }

    // MARK: Surface
    // Small surfaces, forms that belongs to an isolated element and/or components
    enum Surface {
        public static let lowAlt = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1.0)
    }
}
