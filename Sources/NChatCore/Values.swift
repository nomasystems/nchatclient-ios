// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import XMPPCore

/// Jabber identifier as specified in [RFC6122](https://tools.ietf.org/html/rfc6122).
///
/// # Examples
///     let user = "100000006122345@chat-core.com/ios"
///     let queue = "0@chat-core.com"
/// - SeeAlso: [RFC6122](https://tools.ietf.org/html/rfc6122)
public typealias Jid = String

public enum FileUploadMode {
    /// Attached files are sent and received in base64 format inside the message body.
    case raw

    /// An endpoint (*slot*) is offered server side where files can be uploaded to and downloaded from.
    case slot
}

/// Defines the parameters to setup a chat connection.

/// States of the chat.
public enum ChatState {
    /// Initial state, ready to connect.
    case initialized
    /// Connecting to the server and joining the queue.
    case pending
    /// Waiting for an agent.
    case queued
    /// Chat is in progress
    case active
    /// In process of being closed.
    case closing
    /// Chat is closed and can't be interacted with it anymore.
    case closed
    /// Chat is closed due to an error and can't be interacted with it anymore.
    case error
}

/// Defines a message from the chat.
public class ChatMessage {
    /// Text of the message.
    public let text: String
    /// Date of the message, locally generated when sent of received.
    public let timestamp: Date

    init(text: String, timestamp: Date) {
        self.text = text
        self.timestamp = timestamp
    }
}



public class PreferredAgent {
    /// Preferred user jid
    public let userJid: String?
    /// Preferred user name
    public let userName: String?
    /// Preferred user login
    public let userLogin: String?

    /**
     Creates a new PreferredAgent.

     - Parameters:
     - userJid: Jid used of the preferred agent.
     - userName: Username used of the preferred agent.
     - userLogin: UserLogin used of the preferred agent.
     */
    public init(userJid: String? = nil,
                userName: String? = nil,
                userLogin: String? = nil) {
        self.userJid = userJid
        self.userName = userName
        self.userLogin = userLogin
    }
}

/**
 Defines data of the particular user connecting to the chat.

 All fields are optional. Those marked as metadata will only be used to be sent when joining the chat.
 */
public struct ChatUserData {
    /// Attachments that the user might send during the chat.
    public let attachments: [ChatAttachment]
    /// Country code of the user. Metadata.
    public let countryCode: String?
    /// Email of the user. Metadata.
    public let email: String?
    /// Name of the user. Metadata.
    public let name: String?
    /// Location (e.g. view) from where the user opened the chat. Metadata.
    public let location: String?
    /// Identifier of the user's product. Metadata.
    public let productSku: String?
    /// Identifier of the user's order. Metadata.
    public let orderId: String?
    /// Topic of the chat
    public let topic: String?
    /// Jid used to connect to the chat.
    ///
    /// If not specified, a random one will be generated.
    /// # Example
    ///     "100000006122345@chat-core.com/ios"
    public let userJid: Jid?
    /// Identifier of the user in a third-party sistem. Metadata.
    public let wsuid: Int?
    /// Arbitrary extra user information. Metadata.
    public let contactMetadata: [String: String]
    /// Preferred agent
    public let preferredAgent: PreferredAgent?
    /// Show/unshow the agen availability (status)
    public let displayAgentAvailability: Bool

    /**
     Creates a new ChatUserData.

     - Parameters:
     - attachments: Attachments that the user might send during the chat.
     - countryCode: Country code of the user.
     - email: Email of the user.
     - name: Name of the user.
     - location: Location (e.g. view) from where the user opened the chat.
     - productSku: Identifier of the user's product.
     - orderId: Identifier of the user's order.
     - topic: Topic of the chat.
     - userJid: Jid used to connect to the chat.
     - wsuid: Identifier of the user in a third-party sistem.
     - contactMetadata: Additional metadata.
     - displayAgentAvailability: Displays the agent avalability (status)
     */
    public init(attachments: [ChatAttachment] = [],
                countryCode: String? = nil,
                email: String? = nil,
                name: String? = nil,
                location: String? = nil,
                productSku: String? = nil,
                orderId: String? = nil,
                topic: String? = nil,
                userJid: String? = nil,
                wsuid: Int? = nil,
                contactMetadata: [String: String] = [:],
                preferredAgent: PreferredAgent? = nil,
                displayAgentAvailability: Bool = true) {
        self.attachments = attachments
        self.countryCode = countryCode
        self.email = email
        self.name = name
        self.location = location
        self.productSku = productSku
        self.topic = topic
        self.orderId = orderId
        self.userJid = userJid
        self.wsuid = wsuid
        self.contactMetadata = contactMetadata
        self.preferredAgent = preferredAgent
        self.displayAgentAvailability = displayAgentAvailability
    }
}
