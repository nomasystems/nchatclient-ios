// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public struct ChatConfiguration {
    /// Url to connect to the chat via the XMPP protocol.
    ///
    /// It might have a format such as `https://host:5280/http-bind`
    public let url: URL
    /// Jid of the queue to connect.
    public let queueJid: Jid
    /// Jid of the domain to upload files.
    public let uploadDomain: Jid
    /// Particulars of the user connecting to the chat.
    public let userData: ChatUserData
    /// Mode of uploading attached files in messages. Defaults to `slot`.
    public let fileUploadMode: FileUploadMode

    public init(url: URL,
                queueJid: Jid,
                uploadDomain: Jid,
                userData: ChatUserData,
                fileUploadMode: FileUploadMode = .slot) {
        self.url = url
        self.queueJid = queueJid
        self.uploadDomain = uploadDomain
        self.userData = userData
        self.fileUploadMode = fileUploadMode
    }
}
