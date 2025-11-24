//
//  Copyright © Nomasystems S.L.. All rights reserved.
//

import NChatCore
import UIKit

protocol ChatInputAccessoryViewDelegate: AnyObject {
    func send(chatInputAccessoryView view: ChatInputAccessoryView, message: String) -> Bool
    func attach()
    func didBeginComposing()
    func didEndComposing()
    func didChangeText(newInput: String)
}

final class ChatInputAccessoryView: UIView {

    private enum Constants {
        static let iconWidth: CGFloat = 40.0
    }

    @IBOutlet private weak var attachButton: UIButton!
    @IBOutlet weak var textView: GrowingTextView!
    @IBOutlet private weak var sendButton: UIButton!

    var productAttachment: ChatAttachment?
    weak var chatInputAccessoryViewDelegate: ChatInputAccessoryViewDelegate?

    var editable: Bool = true {
        didSet {
            attachButton.isEnabled = editable
            textView.isEditable = editable
            sendButton(enabled: editable && !textView.text.isEmpty)
            UIView.animate(withDuration: 0.2) {
                self.attachButton.alpha = self.editable ? 1.0 : 0.5
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Add top border
        let border = CALayer()
        border.backgroundColor = UIColor.lightGray.cgColor
        border.frame = CGRect(x: 20, y: 0, width: bounds.width - 40, height: 1)
        layer.addSublayer(border)
        setupLocalizedStrings()
    }

    func setup(placerHolderMessageFont: UIFont, sendButtonFont: UIFont) {
        textView.font = placerHolderMessageFont
        sendButton.titleLabel?.font = sendButtonFont
    }

    @IBAction func sendButtonTouchUpInside(_ sender: UIButton) {
        guard let delegate = chatInputAccessoryViewDelegate else { return }
        let message = textView.text.maskingPrivateInfo()
        if delegate.send(chatInputAccessoryView: self, message: message) {
            textView.text = ""
            sendButton(enabled: false)
            chatInputAccessoryViewDelegate?.didChangeText(newInput: "")
        }
    }

    @IBAction func attachButtonTouchUpInside(_ sender: UIButton) {
        chatInputAccessoryViewDelegate?.attach()
    }

    func setAttachButton(enabled: Bool) {
        attachButton.isEnabled = enabled
    }
}

private extension ChatInputAccessoryView {
    func setupLocalizedStrings() {
        sendButton.setTitle(SampleChat.localization.sendCapitalized, for: .normal)
        textView.placeHolder = SampleChat.localization.writeMessageEllipsisPlaceholder as NSString?
    }

    func sendButton(enabled isEnabled: Bool) {
        if sendButton.isEnabled != isEnabled { // Don't trigger any animation if it's not necessary
            sendButton.isEnabled = isEnabled
            UIView.animate(withDuration: 0.5) {
                self.sendButton.alpha = isEnabled ? 1 : 0.5
            }
        }
    }
}

extension ChatInputAccessoryView: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        chatInputAccessoryViewDelegate?.didBeginComposing()
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        chatInputAccessoryViewDelegate?.didEndComposing()
    }

    public func textViewDidChange(_ textView: UITextView) {
        sendButton(enabled: !textView.text.isEmpty)
        chatInputAccessoryViewDelegate?.didChangeText(newInput: textView.text)
    }
}
