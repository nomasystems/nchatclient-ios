import UIKit

extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }

    func removeArrangedSubviews(block: ((UIView) -> Void)? = nil) {
        arrangedSubviews.forEach {
            block?($0)
            $0.removeFromSuperview()
        }
    }

    func removeArrangedSubviews(where condition: (UIView) -> Bool) {
        arrangedSubviews.forEach {
            if condition($0) {
                $0.removeFromSuperview()
            }
        }
    }
}
