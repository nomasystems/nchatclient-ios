// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import XMPPCore

protocol WorkgroupDelegate: AnyObject {
    func joined(workgroup: Workgroup, success: Bool)
    func notification(workgroup: Workgroup, text: String)
    func invite(workgroup: Workgroup, room: Room)
}

class Workgroup {
    weak var delegate: WorkgroupDelegate?
    private weak var client: Client?
    let jid: XMPPJid
    private let userData: ChatUserData
    private var room: Room?

    init(client: Client, jid: XMPPJid, userData: ChatUserData) {
        self.client = client
        self.jid = jid
        self.userData = userData
    }

    func queue(completion: @escaping (XMPPIq) -> Void) {
        let crm = userData.crmXmlMetadata(contactJid: client?.jid)
        let iq = XMPPIq(type: .set, id: "workgroup-join-1", to: jid, data: [
            XMLParserEl.node(name: "join-queue", namespace: .WORKGROUP,
                                children: [crm, XMLParserEl.node(name: "queue-notifications")])
        ])

        client?.send(iq: iq) { result in
            completion(result)
            self.delegate?.joined(workgroup: self, success: result.type == .result)
        }
        XMPPLog("WORKGROUP", "Queuing \(jid)")
    }

    func on(invite room: Room, from: XMPPJid) {
        guard room.jid != self.room?.jid else { return }
        self.room = room
        delegate?.invite(workgroup: self, room: room)
        XMPPLog("WORKGROUP", "Associated room \(room.jid)")
    }
}

extension Workgroup: RosterPeer {
    func match(jid: XMPPJid) -> Bool {
        return jid == self.jid
    }

    func on(state: RosterPeerState, for jid: XMPPJid) {
    }

    func on(message: XMPPMessage, from: XMPPJid, text: String) {
        delegate?.notification(workgroup: self, text: text)
        XMPPLog("WORKGROUP", "Notification \(from)")
    }

    func on(message: XMPPMessage, state: Room.Message.State, id: String?) {
    }
}

private extension ChatUserData {
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

private extension Date {
    func toISOString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter.string(from: self)
    }
}
