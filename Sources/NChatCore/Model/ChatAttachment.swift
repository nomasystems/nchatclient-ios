// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

/**
 Defines an attachment to be sent through the chat.

 Attachments can be used to send files through the chat.
 Currently only image attachments are supported and they travel in-band,
 this means that the conversation is locked while the attachment is being sent.
 */
open class ChatAttachment {

    /// Data of the document
    public var data: Data
    /// Title of the attachment.
    public let title: String?
    /// URL with more information regarding the attachment.
    public let url: URL?
    /// Format of the attachment
    public let pathExtension: String?

    /**
     Creates a new ChatAttachment.

     - Parameters:
     - title: Title of the attachment.
     - url: URL with more information regarding the attachment.
     - pathExtension: Extension of the file
     - data: Data of the attachement.
     */
    public init(data: Data,
                title: String? = nil,
                url: URL? = nil,
                pathExtension: String? = nil) {
        self.data = data
        self.title = title
        self.url = url
        self.pathExtension = pathExtension
    }
}
