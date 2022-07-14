// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation
import XMPPCore

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
    /// Topic of the chat. Metadata.
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


extension ChatUserData {
    func crmXmlMetadata(contactJid: XMPPJid?) -> XMLParserEl {
        let currentVersion = Bundle(for: Workgroup.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.x"
        let baseMetadata: [String: String?] = [
            "beginTime": Date().toISOString(),
            "contactCountryCode": countryCode,
            "contactDevice": "ios",
            "contactEmail": email,
            "contactJid": contactJid?.description,
            "contactName": name,
            "contactOrderId": orderId,
            "contactPage": location,
            "contactSku": productSku,
            "contactTopic": topic,
            "contactWcsuid": wsuid.flatMap {String($0)},
            "helpClientVersion": currentVersion,
            "isMediaDeriverableToCustomer": "true",
            "preferredUserJid": preferredAgent?.userJid,
            "preferredUserName": preferredAgent?.userName,
            "preferredUserLogin": preferredAgent?.userLogin
        ]

        var xmlMetadata = baseMetadata.map { (key, value) in
            XMLParserEl.node(name: key, children: [XMLParserEl.text(value ?? "")])
        }
        if !contactMetadata.isEmpty {
            let xmlContactMetadata = contactMetadata.map { (key, value) in
                XMLParserEl.node(name: key, children: [XMLParserEl.text(value)])
            }
            xmlMetadata.append(XMLParserEl.node(name: "contactMetadata", children: xmlContactMetadata))
        }
        return XMLParserEl.node(name: "crm", children: xmlMetadata)
    }
}
