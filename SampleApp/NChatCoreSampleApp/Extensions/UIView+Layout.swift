import UIKit

extension UIView {
    var isLayoutRightToLeft: Bool {
        effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    var borderColor: UIColor? {
        set {
            layer.borderColor = newValue?.cgColor
        }
        get {
            guard let color = layer.borderColor else {
                return nil
            }
            return UIColor(cgColor: color)
        }
    }

    var borderWidth: CGFloat {
        set {
            layer.borderWidth = newValue
        }
        get {
            layer.borderWidth
        }
    }

    static func initForAutoLayout() -> Self {
        let view = Self.init(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
