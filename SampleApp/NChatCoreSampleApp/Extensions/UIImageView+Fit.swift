import UIKit

extension UIImageView {
    func fitToSuperview(with insets: UIEdgeInsets) {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left),
            topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top),
            superview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: insets.right),
            superview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)
        ])
    }
}
