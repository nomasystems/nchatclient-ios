//
//  Copyright © Nomasystems S.L.. All rights reserved.
//

import NChatCore

import UIKit

protocol ChatBubbleTableViewCellDelegate: AnyObject {
    func didSelect(button: Button)
    func userWantsToZoom(image: UIImage)
}

private struct QuickAnswerButton {
    let uiButton: UIButton
    let messageButton: Button
}

public final class ChatBubbleTableViewCell: UITableViewCell {

    // MARK: View properties

    @IBOutlet private weak var content: ContentView!
    @IBOutlet private weak var status: StatusView!
    @IBOutlet private weak var bubbleView: UIView!
    @IBOutlet private weak var dateBubbleContainerView: UIView!
    @IBOutlet private weak var topicLabelContainerView: UIView!
    @IBOutlet private weak var topicLabel: UILabel!
    @IBOutlet private weak var dateBubbleLabel: LabelWithMargins!
    @IBOutlet private var topicLabelTopMargin: NSLayoutConstraint?
    @IBOutlet private var dateBubbleTopMargin: NSLayoutConstraint?
    @IBOutlet private var bottomMargin: NSLayoutConstraint?

    // MARK: Properties

    static let inboundReuseIdentifier = "inbound"
    static let outboundReuseIdentifier = "outbound"
    private weak var delegate: ChatBubbleTableViewCellDelegate?
    private var quickAnswerButtons: [QuickAnswerButton] = []
    private var message: Room.Message?


    // MARK: Initialization

    override public func awakeFromNib() {
        super.awakeFromNib()
        contentView.autoresizingMask = .flexibleHeight
        content.attachmentView.clipsToBounds = true
        content.setCustomSpacing(Spacer.size03, after: status)
        // TODO: review style
        //topicLabel?.style = .paragraphS
        topicLabel?.backgroundColor = .Background.base
        topicLabel?.textColor = .Content.mid
        topicLabel?.textAlignment = .center
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        content.messageTextView.text = nil
        gestureRecognizers?.forEach(removeGestureRecognizer(_:))
        quickAnswerButtons = []
        content.removeArrangedSubviews { $0 is UIButton }
        topicLabelContainerView?.isHidden = true
        dateBubbleContainerView?.isHidden = true
    }

    // MARK: Public setup methods

    func configure(delegate: ChatBubbleTableViewCellDelegate, urlHandler: ChatURLHandlerProtocol? = nil) {
        self.delegate = delegate
        content.urlHandler = urlHandler
    }

    func display(message: Room.Message) {
        self.message = message
        setupBackground()

        // Timestamp setup
        updateTimestamp()

        // Text setup
        let text: String = {
            let text: String
            if message.text.isEmpty, let buttonText = message.buttonText {
                text = buttonText
            } else {
                text = message.text.maskingPrivateInfo()
            }

            return text
        }()
        content.messageTextView.text = text
        content.messageTextView.isHidden = text.isEmpty

        // Hyperlinks setup
        if message.text.range(of: ChatBubbleTableViewCell.hyperlinkPattern, options: .regularExpression) != nil,
           let text = content.messageTextView.text {
            let hyperlinks = ChatBubbleTableViewCell.extractHyperlinks(in: text, matching: ChatBubbleTableViewCell.hyperlinkPattern)
            content.messageTextView.attributedText = content.messageTextView.attributedText.formatLinks(in: text, hyperlinks: hyperlinks)
        }
    }

    func setup(buttons: [Button], bubblesDelegate: ChatBubblesDelegate?) {
        quickAnswerButtons = []
        content.setCustomSpacing(Spacer.size02, after: content.messageTextView)
        for button in buttons {
            let quickAnswerButton = buildButton(for: button, bubblesDelegate: bubblesDelegate)
            quickAnswerButtons.append(quickAnswerButton)
            if let messageTextViewIndex = content.arrangedSubviews.firstIndex(where: { $0 == content.messageTextView }),
               messageTextViewIndex + 1 < content.arrangedSubviews.count {
                content.insertArrangedSubview(quickAnswerButton.uiButton, at: messageTextViewIndex + 1)
            }
            content.setCustomSpacing(Spacer.size02, after: quickAnswerButton.uiButton)
        }
    }

    func display(placeholder: String) {
        setupBackground()
        status.isHidden = true
        bottomMargin?.constant = .zero
        content.messageTextView.text = placeholder
    }

    func setup(topic: String) {
        topicLabelContainerView?.isHidden = false
        topicLabel?.text = topic
        topicLabelTopMargin?.constant = Spacer.size04
    }

    func setup(bubbleDate: Date,
               font: UIFont?,
               textColor: UIColor?) {
        dateBubbleContainerView?.isHidden = false
        dateBubbleLabel?.setup(with: bubbleDate.bubbleFormat,
                               font: font ?? .systemFont(ofSize: 11),
                               textColor: textColor ?? .Content.mid)
        dateBubbleTopMargin?.constant = Spacer.size04
    }

    func setFonts(messageFont: UIFont, timestampFont: UIFont) {
        content.messageTextView.font = messageFont
        status.timestampLabel.font = timestampFont
    }

    // MARK: Static - Hyperlinks

    /**
    Matches 1+ occurrences of [text|link]
    Returns a dict with hyperlinks associated to text hyperlinked.
    Example with "By accepting this, you accept [terms|https://www.google.com] and [conditions|https://www.amazon.com]":
    ▿ 2 elements
    ▿ 0 : 2 elements
      - key : "terms"
      - value : "https://www.google.com"
    ▿ 1 : 2 elements
      - key : "conditions"
      - value : "https://www.amazon.com"
    */
    static func extractHyperlinks(in text: String, matching pattern: String) -> [String: String] {
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var hyperlinks: [String: String] = [:]
        if let matches = matches, !matches.isEmpty {
            for match in matches {
                let location = match.range(at: 0).location
                let offset = match.range(at: 0).length - 1
                let startIndex = text.index(text.startIndex, offsetBy: location + 1) // +1 removes opening bracket
                let endIndex = text.index(text.startIndex, offsetBy: location + offset - 1) // -1 removes closing bracket
                let substring = text[startIndex...endIndex]
                let splits = substring.components(separatedBy: "|")
                guard splits.count == 2, URL(string: splits[1].trimmingCharacters(in: .whitespacesAndNewlines)) != nil
                else { continue }
                hyperlinks[splits[0]] = splits[1]
            }
        }
        return hyperlinks
    }

    static var hyperlinkPattern: String {
        let allCharsExceptBracketAndPipe = "[^\\|\\[\\]]+"
        let pattern = "\\[" + allCharsExceptBracketAndPipe + "\\|" + allCharsExceptBracketAndPipe + "\\]"
        return pattern
    }
}

// MARK: - Private

private extension ChatBubbleTableViewCell {

    func updateTimestamp() {
        status.clockIconView.isHidden = message?.isDelivered == true
        status.timestampLabel.text = message?.timestamp.formatTimestamp()
    }

    func setupBackground() {
        let isUserMsg = message?.from == .user
        let imageName = isUserMsg ? "bubbleChatRight" : "bubbleChatLeft"
        let image = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil)

        let view = UIImageView(image: image)
        if isLayoutRightToLeft {
            // For right-to-left languages support, we manually mirror the background chat bubble image
            // as native iOS support doesn't seem to work well due to resizable image assets.
            view.transform = CGAffineTransform(scaleX: -1, y: 1)
        }

        bubbleView.addSubview(view)
        bubbleView.sendSubviewToBack(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        let paddingX: CGFloat = Spacer.size06
        let paddingY: CGFloat = Spacer.size02
        let offsetX: CGFloat = isUserMsg ? 2 : -4
        let offsetY: CGFloat = .zero
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: bubbleView.widthAnchor, constant: paddingX),
            view.heightAnchor.constraint(equalTo: bubbleView.heightAnchor, constant: paddingY),
            view.centerXAnchor.constraint(equalTo: bubbleView.centerXAnchor, constant: offsetX),
            view.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor, constant: offsetY)
        ])
    }

    // MARK: Buttons


    func buildButton(for button: Button, bubblesDelegate: ChatBubblesDelegate?) -> QuickAnswerButton {
        let uiButton = UIButton.initForAutoLayout()

        uiButton.titleLabel?.font = bubblesDelegate?.fontForBubbleMessage()
        uiButton.setTitleColor(bubblesDelegate?.customTextColorForBubbleButton ?? .Content.high, for: .normal)
        uiButton.backgroundColor = bubblesDelegate?.customBackgroundColorForBubbleButton ?? .white

        let height = bubblesDelegate?.customHeightForBubbleButton ?? 40.0
        uiButton.heightAnchor.constraint(equalToConstant: height).isActive = true

        if bubblesDelegate?.borderForBubbleButton() ?? false {
            uiButton.layer.borderColor = bubblesDelegate?.customBorderColorForBubbleButton?.cgColor ?? UIColor.Content.high.cgColor
            uiButton.layer.borderWidth  = bubblesDelegate?.customBorderWidthForBubbleButton ?? 1.0
            uiButton.layer.cornerRadius  = bubblesDelegate?.customBorderRadiusForBubbleButton ?? 0.0
        }

        uiButton.setTitle(button.text, for: .normal)
        uiButton.addTarget(self, action: #selector(buttonTouchUpInside), for: .touchUpInside)

        return QuickAnswerButton(uiButton: uiButton, messageButton: button)
    }

    @objc func buttonTouchUpInside(sender: UIButton) {
        guard let button = quickAnswerButtons.first(where: { $0.uiButton == sender })?.messageButton
        else { return }
        // Stop showing options once user selects one.
        let buttons = quickAnswerButtons.compactMap { $0.uiButton }
        for button in buttons {
            button.removeFromSuperview()
        }
        delegate?.didSelect(button: button)
    }
}

// MARK: - NSAttributedString

private extension NSAttributedString {
    func formatLinks(in text: String, hyperlinks: [String: String]) -> NSAttributedString {
        var result = self
        let existingAttributes = result.attributes(at: 0, effectiveRange: nil)
        for hyperlink in hyperlinks {
            if text.contains(hyperlink.key), let url = URL(string: hyperlink.value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let replacement = "[" + hyperlink.key + "|" + hyperlink.value + "]"
                result = result.insert(url: url, in: hyperlink.key, replacement: replacement, attributes: existingAttributes)
            }
        }
        return result
    }

    func insert(url: URL, in text: String, replacement: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        let hyperlinkedText = NSMutableAttributedString(string: text, attributes: attributes)
        if UIApplication.shared.canOpenURL(url) {
            hyperlinkedText.addAttributes([.link: url], range: NSRange(location: 0, length: hyperlinkedText.string.count))
        }
        let range = (self.string as NSString).range(of: replacement)
        result.replaceCharacters(in: range, with: hyperlinkedText)
        return result
    }
}

// MARK: - Methods that allow to copy on long press

extension ChatBubbleTableViewCell {

    override public var canBecomeFirstResponder: Bool { return true }

    func allowCopyMessage() {
        guard let msg = content.messageTextView.text, !msg.isEmpty else { return }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        addGestureRecognizer(recognizer)
    }

    @objc private func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began, let view = gestureRecognizer.view else { return }
        becomeFirstResponder()
        var messageLabelMiddleRect: CGRect {
            CGRect(x: content.frame.origin.x + content.messageTextView.frame.origin.x + content.messageTextView.frame.size.width / 2,
                   y: content.frame.origin.y + content.messageTextView.frame.origin.y,
                   width: .zero,
                   height: .zero)
        }
        UIMenuController.shared.showMenu(from: view, rect: messageLabelMiddleRect)
    }

    override public func copy(_ sender: Any?) {
        UIPasteboard.general.string = content.messageTextView.text
    }

    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:))
    }
}

// MARK: - UITraitEnvironment

extension ChatBubbleTableViewCell {
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection != traitCollection else { return }
        setupBackground()
    }
}

// MARK: - Other classes

final class ContentView: UIStackView, UITextViewDelegate {
    @IBOutlet var attachmentView: UIView!
    @IBOutlet var messageTextView: UITextView!
    var urlHandler: ChatURLHandlerProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
        messageTextView.text = nil
        messageTextView.delegate = self
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        guard let handler = urlHandler else { return true }

        handler.handle(URL)
        return false
    }
}

final class StatusView: UIStackView {
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var clockIconView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        timestampLabel.text = nil
        timestampLabel.textColor = .Content.mid
    }
}
