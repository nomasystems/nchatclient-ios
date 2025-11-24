import UIKit

extension UIColor {

    enum Constants {
        enum Light {
            static let attachmentProductTitleTextColor: UIColor = .black
            static let attachmentProductColorTextColor: UIColor = .black
            static let attachmentProductDescriptionTextColor: UIColor = .init(white: 0.50, alpha: 1)
            static let attachmentProductLinkTextColor: UIColor = .init(white: 0.40, alpha: 1)
            static let attachmentProductBackgroundColor: UIColor = .white
            static let navigationTitleTextColor: UIColor = .black
            static let labelTextColor: UIColor = .black
        }

        enum Dark {
            static let attachmentProductTitleTextColor: UIColor = .white
            static let attachmentProductColorTextColor: UIColor = .init(white: 0.40, alpha: 1)
            static let attachmentProductDescriptionTextColor: UIColor = .init(white: 0.60, alpha: 1)
            static let attachmentProductLinkTextColor: UIColor = .init(white: 0.40, alpha: 1)
            static let attachmentProductBackgroundColor: UIColor = .clear
            static let navigationTitleTextColor: UIColor = .white
            static let labelTextColor: UIColor = .init(white: 0.60, alpha: 1)
        }
    }

    static func attachmentProductTitleTextColor(traits: UITraitCollection, style: PreferredAppearance) -> UIColor {
        correspondingColor(darkModeColor: Constants.Dark.attachmentProductTitleTextColor,
                           defaultColor: Constants.Light.attachmentProductTitleTextColor,
                           preferredAppearance: style)
    }

    static func attachmentProductColorTextColor(traits: UITraitCollection, style: PreferredAppearance) -> UIColor {
        correspondingColor(darkModeColor: Constants.Dark.attachmentProductColorTextColor,
                           defaultColor: Constants.Light.attachmentProductColorTextColor,
                           preferredAppearance: style)
    }

    static func attachmentProductDescriptionTextColor(traits: UITraitCollection, style: PreferredAppearance) -> UIColor {
        correspondingColor(darkModeColor: Constants.Dark.attachmentProductDescriptionTextColor,
                           defaultColor: Constants.Light.attachmentProductDescriptionTextColor,
                           preferredAppearance: style)
    }

    static func attachmentProductLinkTextColor(traits: UITraitCollection, style: PreferredAppearance) -> UIColor {
        correspondingColor(darkModeColor: Constants.Dark.attachmentProductLinkTextColor,
                           defaultColor: Constants.Light.attachmentProductLinkTextColor,
                           preferredAppearance: style)
    }

    static func attachmentProductBackgroundColor(traits: UITraitCollection, style: PreferredAppearance) -> UIColor {
        correspondingColor(darkModeColor: Constants.Dark.attachmentProductBackgroundColor,
                           defaultColor: Constants.Light.attachmentProductBackgroundColor,
                           preferredAppearance: style)
    }

    static func attachmentTextSeparatorColor() -> UIColor {
        UIColor(white:0.58, alpha: 1)
    }

    static let navigationTitleTextColor: UIColor = {
        correspondingColor(darkModeColor: Constants.Dark.navigationTitleTextColor,
                           defaultColor: Constants.Light.navigationTitleTextColor)
    }()

    static let labelTextColor: UIColor = {
        correspondingColor(darkModeColor: Constants.Dark.labelTextColor,
                           defaultColor: Constants.Light.labelTextColor)
    }()

    enum PreferredAppearance {
        case forcedLight
        case inheritedAppearance
    }

    fileprivate static func correspondingColor(darkModeColor: UIColor, defaultColor: UIColor, preferredAppearance: PreferredAppearance = .inheritedAppearance) -> UIColor {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if preferredAppearance == .forcedLight {
                return defaultColor
            }
            return traitCollection.userInterfaceStyle == .dark ? darkModeColor : defaultColor
        }
    }
}
