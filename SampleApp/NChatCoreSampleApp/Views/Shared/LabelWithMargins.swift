//Copyright 2025

import UIKit

class LabelWithMargins: UILabel {

    var radiusCorner: CGFloat = 12
    var verticalMargins: CGFloat = 4
    var horizontalMargins: CGFloat = 8

    private var textInsets: UIEdgeInsets {
        return UIEdgeInsets(
            top: verticalMargins,
            left: horizontalMargins,
            bottom: verticalMargins,
            right: horizontalMargins)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        clipsToBounds = true
        layer.cornerRadius = radiusCorner
        backgroundColor = .systemBackground
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetsRect = bounds.inset(by: self.textInsets)
        let textRect = super.textRect(forBounds: insetsRect, limitedToNumberOfLines: numberOfLines)
        let removedInsets = UIEdgeInsets(
            top: -textInsets.top,
            left: -textInsets.left,
            bottom: -textInsets.bottom,
            right: -textInsets.right)

        return textRect.inset(by: removedInsets)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.textInsets))
    }

    public func setup(with text: String, font: UIFont, textColor: UIColor) {
        isHidden = false
        self.text = text
        self.font = font
        self.textColor = textColor
    }

}
