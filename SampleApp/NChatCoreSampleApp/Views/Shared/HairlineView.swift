import UIKit

public class HairlineView: UIView {

    // MARK: - Properties

    /// Use UIAppearance proxy to customize color throughout app:
    /// `HairlineView.appearance().hairLineColor = .red`
    @objc dynamic var hairLineColor: UIColor? {
        get { return self.backgroundColor }
        set { self.backgroundColor = newValue }
    }

    /// Returns the physical pixel width (1.0 / scale)
    static var pixelWidth: CGFloat {
        return 1.0 / UIScreen.main.scale
    }

    // MARK: - Factory Methods

    /// Creates a hairline view without any constraints.
    static func create() -> HairlineView {
        let view = HairlineView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// Add a hairline to a view.
    /// - Parameters:
    ///   - view: The parent view to add the hairline to.
    ///   - attribute: Alignment of the separator (Top, Bottom, Left, Right, Leading, Trailing).
    ///   - constant: Offset margin from the alignment attribute.
    ///   - leadingMargin: Leading/Top margin relative to the parent view.
    ///   - trailingMargin: Trailing/Bottom margin relative to the parent view.
    /// - Returns: The created HairlineView instance.
    @discardableResult
    static func add(to view: UIView,
                    alignedTo attribute: NSLayoutConstraint.Attribute,
                    constant: CGFloat = 0,
                    leadingMargin: CGFloat = 0,
                    trailingMargin: CGFloat = 0) -> HairlineView {

        let width = HairlineView.pixelWidth
        let hairLineView = HairlineView.create()
        view.addSubview(hairLineView)

        var isHorizontal = false

        switch attribute {
        case .top, .bottom:
            isHorizontal = true
        case .left, .right, .leading, .trailing:
            isHorizontal = false
        default:
            fatalError("Unsupported attribute for alignment")
        }

        // 1. Dimension Constraint (Thickness)
        let dimensionConstraint: NSLayoutConstraint
        if isHorizontal {
            dimensionConstraint = hairLineView.heightAnchor.constraint(equalToConstant: width)
        } else {
            dimensionConstraint = hairLineView.widthAnchor.constraint(equalToConstant: width)
        }

        // 2. Alignment Constraint (Position relative to parent edge)
        // We use NSLayoutConstraint(item:...) because the attribute is dynamic
        let align = NSLayoutConstraint(item: hairLineView,
                                       attribute: attribute,
                                       relatedBy: .equal,
                                       toItem: view,
                                       attribute: attribute,
                                       multiplier: 1,
                                       constant: constant)

        // 3. Leading/Trailing Constraints (Stretch)
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint

        if isHorizontal {
            leading = hairLineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin)
            trailing = hairLineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -trailingMargin)
        } else {
            leading = hairLineView.topAnchor.constraint(equalTo: view.topAnchor, constant: leadingMargin)
            trailing = hairLineView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -trailingMargin)
        }

        NSLayoutConstraint.activate([dimensionConstraint, align, leading, trailing])

        return hairLineView
    }
}
