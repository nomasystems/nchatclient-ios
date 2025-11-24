//
//  GrowingTextView.swift
//  Based on https://github.com/KennethTsang/GrowingTextView
//  Created by Kenneth Tsang on 17/2/2016.
//  Copyright (c) 2016 Kenneth Tsang. All rights reserved.
//

import Foundation
import UIKit

@objc protocol GrowingTextViewDelegate: UITextViewDelegate {
    @objc optional func textViewDidChangeHeight(_ textView: GrowingTextView, height: CGFloat)
}

final class GrowingTextView: UITextView {

    // Maximum length of text. 0 means no limit.
    public var maxLength: Int = 0

    // Trim white space and newline characters when end editing. Default is true
    public var trimWhiteSpaceWhenEndEditing: Bool = true

    // Maximum height of the textview
    public var maxHeight: CGFloat = .zero

    // Placeholder properties
    // Need to set both placeHolder and placeHolderColor in order to show placeHolder in the textview
    public var placeHolder: NSString? {
        didSet { setNeedsDisplay() }
    }
    public var placeHolderColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    public var placeHolderLeadingMargin: CGFloat = 5 {
        didSet { setNeedsDisplay() }
    }

    override public var text: String! {
        didSet {
            setNeedsDisplay()
        }
    }

    private var heightConstraint: NSLayoutConstraint?

    // Initialize
    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 34)
    }

    func associateConstraints() {
        // iterate through all text view's constraints and identify
        // height,from: https://github.com/legranddamien/MBAutoGrowingTextView
        for constraint in constraints where constraint.firstAttribute == .height && constraint.relation == .equal {
            heightConstraint = constraint
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Listen to UITextView notification to handle trimming, placeholder and maximum length
    private func commonInit() {
        self.contentMode = .redraw
        associateConstraints()
        configureForRightToLeftLanguages()
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidEndEditing), name: UITextView.textDidEndEditingNotification, object: self)
    }

    // Calculate height of textview
    override public func layoutSubviews() {
        super.layoutSubviews()
        let size = contentSize.height > intrinsicContentSize.height ? contentSize : intrinsicContentSize
        var height = size.height
        if maxHeight > 0 {
            height = min(size.height, maxHeight)
        }

        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: height)
            addConstraint(heightConstraint!)
        }

        if height != heightConstraint?.constant {
            heightConstraint?.constant = height
            scrollRangeToVisible(NSRange(location: 0, length: 0))
            if let delegate = delegate as? GrowingTextViewDelegate {
                delegate.textViewDidChangeHeight?(self, height: height)
            }
        }
    }

    // Show placeholder
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        guard text.isEmpty, let placeHolder = placeHolder else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment

        let rect = CGRect(x: textContainerInset.left + (isLayoutRightToLeft ? -1 : 1) * placeHolderLeadingMargin,
                          y: textContainerInset.top,
                          width: frame.size.width - textContainerInset.left - textContainerInset.right,
                          height: frame.size.height)

        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: placeHolderColor,
            .paragraphStyle: paragraphStyle
        ]
        if let font = font {
            attributes[.font] = font
        }

        placeHolder.draw(in: rect, withAttributes: attributes)
    }

    // Trim white space and new line characters when end editing.
    @objc func textDidEndEditing(notification: Notification) {
        guard let notificationObject = notification.object as? GrowingTextView,
              notificationObject === self,
              trimWhiteSpaceWhenEndEditing
        else { return }

        text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        setNeedsDisplay()
    }

    // Limit the length of text
    @objc func textDidChange(notification: Notification) {
        guard let notificationObject = notification.object as? GrowingTextView,
              notificationObject === self
        else { return }

        if maxLength > 0 && text.count > maxLength {
            text = String(text.prefix(maxLength))
            undoManager?.removeAllActions()
        }
        setNeedsDisplay()
    }

    private func configureForRightToLeftLanguages() {
        let language = NSLocale.preferredLanguages.first
        let isRtlLayout = effectiveUserInterfaceLayoutDirection == .rightToLeft
        if isRtlLayout && NSParagraphStyle.defaultWritingDirection(forLanguage: language) == .rightToLeft {
            textAlignment = .right
        } else {
            textAlignment = .left
        }
    }
}
