import UIKit

@objc
public protocol Localizable {

    var chatCapitalized: String { get }
    var sendCapitalized: String { get }
    var closeCapitalized: String { get }
    var cancel: String { get }
    var closedInactivity: String { get }
    var closedStatus: String { get }
    var pendingStatus: String { get }
    var queuedStatus: String { get }
    var connectionFailureString: String { get }
    var connectionErrorString: String { get }
    var internalErrorString: String { get }
    var writeMessageEllipsisPlaceholder: String { get }
    var shareProduct: String { get }
    var shareProductTitle: String { get }
    var shareCamera: String { get }
    var shareMedia: String { get }
    var closeChatAlert : String { get }
    var yes : String { get }
    var no : String { get }
}


class DefaultLocalization: Localizable {

    // MARK: - General translations
    var chatCapitalized: String {
        return "Chat"
    }

    var sendCapitalized: String {
        return "Send"
    }

    var closeCapitalized: String {
        return "Close"
    }

    var cancel: String {
        return "Cancel"
    }

    var closedInactivity: String {
        return "Chat has been closed due to inactivity"
    }

    // MARK: - Status translations
    var closedStatus: String {
        return "Chat is closed"
    }

    var pendingStatus: String {
        return "Connecting..."
    }

    var queuedStatus: String {
        return "Waiting for a support agent..."
    }


    // MARK: - XMPP error translations
    var connectionFailureString: String {
        return "Lost connection to the server"
    }

    var connectionErrorString: String {
        return "Failed to connect to the chat server"
    }

    var internalErrorString: String {
        return "Internal error"
    }

    var reconnectingString: String {
        return "Trying to recover connection..."
    }

    // MARK: - ChatController translations
    var writeMessageEllipsisPlaceholder: String {
        return "Write a message..."
    }

    var shareProduct: String {
        return "Product"
    }

    var shareProductTitle: String {
        return "Share product"
    }

    var shareCamera: String {
        return "Camera"
    }

    var shareMedia: String {
        return "Photo & Video Library"
    }

    // MARK: - Alert translations
    var closeChatAlert : String {
        return "Do you wish to finalize the chat? The current conversation will be lost."
    }

    var yes : String {
        return "Yes"
    }

    var no : String {
        return "No"
    }

}
