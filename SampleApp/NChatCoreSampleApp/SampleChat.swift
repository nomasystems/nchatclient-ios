import Foundation
import UIKit
import NChatCore

typealias RawAttachment = (attachment: ChatAttachment, message: String?)

// MARK: Delegates

@objc public protocol ChatViewDelegate {
    /**
     * Presents an alert for closing the chat.
     */
    func presentCloseChatAlert(message: String, fromViewController: UIViewController, closeButtonAction: @escaping ()->Void)
}

@objc public protocol ChatNoticeDelegate: AnyObject {
    func presentNoticeAction(viewController: UIViewController)
    func noticeMessage() -> NSAttributedString
}

@objc public protocol ChatTopicDelegate: AnyObject {
    func backgroundColourForBubble() -> UIColor
    func textColourForBubble() -> UIColor
    func fontForSystemTimestamp() -> UIFont
}

@objc public protocol ChatBubblesDelegate: AnyObject {
    func fontForBubbleMessage() -> UIFont
    func fontForBubbleTimestamp() -> UIFont
    func fontForBubbleButton() -> UIFont
    func fontForSendButton() -> UIFont
    func fontForWriteAMessagePlaceHolder() -> UIFont

    // Bubble button customisation
    func borderForBubbleButton() -> Bool
    @objc optional func shouldUppercaseTextForBubbleButton() -> Bool
    @objc optional var customBackgroundColorForBubbleButton: UIColor { get }
    @objc optional var customTextColorForBubbleButton: UIColor { get }
    @objc optional var customBorderColorForBubbleButton: UIColor { get }
    @objc optional var customBorderRadiusForBubbleButton: CGFloat { get }
    @objc optional var customBorderWidthForBubbleButton: CGFloat { get }
    @objc optional var customHeightForBubbleButton: CGFloat { get }
    @objc optional var customTrailingForBubbleButton: CGFloat { get }
}

@objc
public protocol ChatNewMessagesDelegate: AnyObject {
    func fontForToastLabels() -> UIFont
    func textColorForToastLabels() -> UIColor
    func backgroundColorForToast() -> UIColor
}

final public class SampleChat: Chat {

    public enum Notifications {
        /// Chat is opened
        public static let chatDidBecomeActive = Notification.Name("com.sample.nchat.didBecomeActive")
        /// Chat is dismissed
        public static let chatDidBecomeInactive = Notification.Name("com.sample.nchat.didBecomeInactive")
    }

    // MARK: - Instance properties

    public weak var noticeDelegate: ChatNoticeDelegate?
    public weak var viewDelegate: ChatViewDelegate?
    public weak var topicDelegate: ChatTopicDelegate?
    public weak var bubblesDelegate: ChatBubblesDelegate?
    public weak var newMessagesDelegate: ChatNewMessagesDelegate?

    static let localization = DefaultLocalization()

    // True when there is an active chat in the background
    var background = false

    var isInputEnabled: Bool {
        room != nil && ![.closing, .closed, .error].contains(state)
    }

    var uniqueMessages: [Room.Message] {
        var uniqueMessages: [Room.Message] = []
        for msg in messages where !uniqueMessages.contains(where: { $0.same(as: msg) }) {
            uniqueMessages.append(msg)
        }
        return uniqueMessages
    }

    var unansweredMessagesNumber: Int {
        if let lastUserMessageIndex = uniqueMessages.reversed().firstIndex(where: { $0.from == .user }) {
            return uniqueMessages.count - lastUserMessageIndex.base
        } else {
            return uniqueMessages.count
        }
    }

    var isConnecting = true

    // MARK: - Class properties and functions

    public static var shared: SampleChat?

    // MARK: Public API

    public static func build(queueJid: String,
                             domain: String,
                             serverUrl: URL,
                             userEmail: String?,
                             userName: String?,
                             userId: String?) -> SampleChat {

        let chatCredentialsManager = ChatCredentialsManager(domain: domain, userId: userId)

        let userData = ChatUserData(attachments: [],
                                    countryCode: "US",
                                    email: userEmail,
                                    name: userName,
                                    location: nil,
                                    productSku: nil,
                                    orderId: nil,
                                    topic: nil,
                                    userJid: chatCredentialsManager.username,
                                    wsuid: nil,
                                    contactMetadata: [:])

        let config = ChatConfiguration(url: serverUrl,
                                       queueJid: queueJid,
                                       uploadDomain: domain,
                                       userData: userData,
                                       fileUploadMode: .raw)

        let chat = SampleChat(configuration: config)
        shared = chat
        return chat
    }

    public static func setupDelegates(noticeDelegate: ChatNoticeDelegate? = nil,
                                      viewDelegate: ChatViewDelegate? = nil,
                                      topicDelegate: ChatTopicDelegate? = nil,
                                      bubblesDelegate: ChatBubblesDelegate? = nil,
                                      newMessagesDelegate: ChatNewMessagesDelegate? = nil) {
        shared?.noticeDelegate = noticeDelegate
        shared?.viewDelegate = viewDelegate
        shared?.topicDelegate = topicDelegate
        shared?.bubblesDelegate = bubblesDelegate
        shared?.newMessagesDelegate = newMessagesDelegate
    }
}
