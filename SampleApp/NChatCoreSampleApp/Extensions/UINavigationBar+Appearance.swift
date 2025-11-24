import UIKit

extension UINavigationBar {

    func setupAppearance(on navigationItem: UINavigationItem) {
        if let title = navigationItem.title?.localizedUppercase {
            let titleLabel = UILabel()
            titleLabel.attributedText = NSAttributedString(string: title, attributes: [.kern: 1.5])
            titleLabel.font = UIFont.systemFont(ofSize: 13)
            titleLabel.textColor = UIColor.navigationTitleTextColor
            titleLabel.sizeToFit()
            navigationItem.titleView = titleLabel
        }
    }
}
