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
