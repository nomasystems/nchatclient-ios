// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import XMPPCore

protocol ClientDelegate: AnyObject {
    func state(client: Client, state: XMPPProtocolState, previous: XMPPProtocolState)
    func error(client: Client, internal: XMPPInternalError)
    func error(client: Client, protocol: XMPPProtocolError)
    func error(client: Client, transport: XMPPTransportError)
    func message(client: Client, sender: XMPPJid, text: String)
    func queued(client: Client, workgroup: Workgroup)
}

class Client: XMPPClientBase {

    // Schedule timer settings
    private let interval = 500
    private let leeway = 250
    private var timer: DispatchSourceTimer?

    weak var delegate: ClientDelegate?
    // Workgroup information
    private let configuration: ChatConfiguration

    // Roster
    var workgroups = [Workgroup]()
    var rooms = [Room]()

    // Randomly generated JID. Useful for restoring previous anonymous chat sessions.
    var randomlyGeneratedJID: String?

    // Custom authentication protocols, provided by the client consumer.
    var authenticationMethods: [AuthenticationMethod] = []

    init(configuration: ChatConfiguration, delegate: ClientDelegate? = nil) {
        self.configuration = configuration
        self.delegate = delegate
    }

    func invalidate() {
        delegate = nil
        workgroups = []
        rooms = []
        disconnect(leavePermanently: false)
    }

    deinit {
        disconnect(leavePermanently: false)
    }

    lazy var randomJid: XMPPJid? = {
        guard let xmppQueueJid = XMPPJid(string: configuration.queueJid) else { return nil }
        let username = Int64.random(in: 100000000000001..<1000000000000000)
        let jidString = String(format: "%llu@%@/ios", username, xmppQueueJid.domain)
        return XMPPJid(string: jidString)
    }()

    func connect() {
        let jid: XMPPJid? = {
            if let jid = configuration.userData.userJid {
                return XMPPJid(string: jid)
            } else {
                return randomJid
            }
        }()
        guard let jid = jid else {
            XMPPLog("ERROR", "Badly formed userJid/queueJid (\(configuration.userData.userJid ?? "-")/\(configuration.queueJid)")
            disconnect(leavePermanently: true)
            return
        }
        if let jid = randomJid?.description {
            randomlyGeneratedJID = jid
            plainDefaultCredentials = (username: jid, password: "anonymous")
        }
        if connect(url: configuration.url, jid: jid) {
            let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(interval), leeway: .milliseconds(leeway))
            timer.setEventHandler { [weak self] in
                self?.processEvents()
            }
            timer.resume()
            self.timer = timer
        }
    }

    func disconnect(leavePermanently: Bool, completion: (() -> Void)? = nil) {
        XMPPLog("Client", "Disconnect: leave permanently \(leavePermanently)")
        if leavePermanently {
            rooms.forEach { $0.leave() }
        } else {
            rooms.forEach { $0.set(available: false) }
        }
        disconnect(completion: completion)
    }

    override func disconnect(completion: (() -> Void)? = nil) {
        timer?.cancel()
        XMPPLog("Client", "Disconnect")
        super.disconnect(completion: completion)
    }

    // MARK: ERROR HANDLING
    override func error(internal error: XMPPInternalError) {
        delegate?.error(client: self, internal: error)
    }

    override func error(protocol error: XMPPProtocolError) {
        delegate?.error(client: self, protocol: error)
    }

    override func error(transport error: XMPPTransportError) {
        delegate?.error(client: self, transport: error)
    }

    // MARK: STATE HANDLING
    override func on(state: XMPPProtocolState, previous: XMPPProtocolState) {
        switch state {
        case .active where previous == .connecting:
            // Initial presence
            send(presence: XMPPPresence())

            // Join the selected queue
            guard let queueJid = XMPPJid(string: configuration.queueJid) else {
                XMPPLog("ERROR", "Badly formed queueJid (\(configuration.queueJid))")
                error(internal: .workgroup())
                return
            }
            let workgroup = Workgroup(client: self, jid: queueJid, userData: configuration.userData)
            workgroups.append(workgroup)
            self.queryAndJoinPreviousRooms(workgroup: workgroup) { queuedOnPreviousRoom in
                if queuedOnPreviousRoom {
                    workgroup.delegate?.joined(workgroup: workgroup, success: queuedOnPreviousRoom)
                } else {
                    workgroup.queue { result in
                        if result.type == .result {
                            self.delegate?.queued(client: self, workgroup: workgroup)
                        } else {
                            let description = result.data.compactMap { $0.getText() }.first
                            self.error(internal: .workgroup(description: description))
                        }
                    }
                }
            }

        default:
            break
        }
        delegate?.state(client: self, state: state, previous: previous)
    }

    // MARK: PRESENCE HANDLING
    override func on(presence: XMPPPresence) {
        presence.data.forEach { node in
            guard case let .node(_, namespace?, _, _) = node else { return }
            switch namespace {
            case .MUC, .MUC_USER, .MUC_ADMIN, .MUC_FEAT:
                handle(presence: presence, muc: node)
            default:
                break
            }
        }
    }

    // MARK: MESSAGE HANDLING
    override func on(message: XMPPMessage) {
        message.data.forEach { node in
            if case let .node(_, namespace?, _, _) = node {
                switch namespace {
                case .CLIENT:
                    handle(message: message, client: node)
                case .CHATSTATE:
                    handle(message: message, state: node)
                case .MUC, .MUC_USER, .MUC_ADMIN, .MUC_FEAT:
                    handle(message: message, muc: node)
                default:
                    break
                }
            } else {
                handle(message: message, unqualified: node)
            }
        }
    }

    // MARK: CLIENT SUBPROTOCOL
    private func handle(message: XMPPMessage, client element: XMLParserEl) {
        guard let from = message.from else { return }
        switch element {
        case .node("body", _, _, _):
            if let room = room(for: from) {
                room.on(message: message, from: from, text: element.getText())
            } else if let workgroup = workgroup(for: from) {
                workgroup.on(message: message, from: from, text: element.getText())
            } else {
                XMPPLog("MESSAGE", "Unknown peer: \(from)")
                delegate?.message(client: self, sender: from, text: element.getText())
            }
        case .node("delivered", _, let attrs, _):
            guard let room = room(for: from) else { return }
            room.on(message: message, state: .delivered, id: attrs["id"])
        case .node("read", _, let attrs, _):
            guard let room = room(for: from) else { return }
            room.on(message: message, state: .read, id: attrs["id"])
        default:
            XMPPLog("MESSAGE", "\(element)")
        }
    }

    // MARK: CHATSTATE SUBPROTOCOL
    private func handle(message: XMPPMessage, state element: XMLParserEl) {
        guard let from = message.from, let room = room(for: from),
              case let .node(name, _, _, _) = element else { return }
        room.on(state: RosterPeerState(string: name), for: from)
    }

    // MARK: MUC SUBPROTOCOL
    private func handle(presence: XMPPPresence, muc element: XMLParserEl) {
        guard let from = presence.from else { return }
        let status = presence.type
        XMPPLog("MUC", "Type \(presence.type) id --> \(presence.id) from --> \(presence)")
        element.forEachElement { e in
            if case let .node("item", _, attrs, _) = e,
               let rawAffiliation = attrs["affiliation"],
               let room = room(for: from) {
                let affiliation = Room.Occupant.Affiliation(string: rawAffiliation)
                room.on(affiliation: affiliation, for: from, status: status)
            }
        }
    }

    private func handle(message: XMPPMessage, muc element: XMLParserEl) {
        guard let from = message.from, let jid = jid else { return }
        element.forEachElement { e in
            guard case let .node("invite", _, attrs, _) = e else { return }
            let roomJid = from.asBare()
            let occupantJid = XMPPJid(jid: roomJid, resource: jid.username)
            let uploadDomain = XMPPJid(string: configuration.uploadDomain)
            let room = rooms.first { $0.jid == roomJid } ??
            Room(client: self, room: roomJid, occupant: occupantJid, uploadDomain: uploadDomain, uploadMode: configuration.fileUploadMode)

            // Is this a room association?
            if let attrsFromJid = attrs["from"]?.jid,
               let wg = workgroup(for: attrsFromJid),
               let messageFrom = message.from {
                wg.on(invite: room, from: messageFrom)
                room.add(member: wg.jid, role: .workgroup)
            }

            if !rooms.contains(where: { $0.jid == roomJid }) {
                rooms.append(room)
                room.set(available: true)
            }

            XMPPLog("MUC", "Invite \(roomJid)")
        }
    }

    // MARK: UNQUALIFIED SUBPROTOCOL
    private func handle(message: XMPPMessage, unqualified element: XMLParserEl) {
        XMPPLog("UNQUALIFIED HANDLE", "element \(element)")
        guard let from = message.from, let room = room(for: from),
              case .node("sent", _, _, _) = element else { return }
        room.on(message: message, state: .sent, id: message.id)
    }

    // MARK: Private Utils
    private func workgroup(for jid: XMPPJid) -> Workgroup? {
        return workgroups.first(where: {$0.match(jid: jid)})
    }

    private func room(for jid: XMPPJid) -> Room? {
        return rooms.first(where: {$0.match(jid: jid)})
    }

    private func queryAndJoinPreviousRooms(workgroup: Workgroup, completion: @escaping (Bool) -> Void) {
        var didFindRoom = false
        guard let jid = jid else {
            completion(didFindRoom)
            return }
        let roomsIq = XMPPIq(type: .get, id: "rooms-get-1", data: [
            XMLParserEl.node(name: "query", namespace: .MUC_ROOMS)
        ])
        send(iq: roomsIq, completion: { [weak self] result in
            guard let self = self else {
                completion(didFindRoom)
                return }
            result.data.first?.forEachElement(completion: { e in
                guard case let .node(_, .MUC_ROOMS, atts, _) = e,
                      let rawRoomJid = atts["jid"],
                      let roomJid = XMPPJid(string: rawRoomJid),
                      !self.rooms.contains(where: { $0.jid == roomJid }) else {
                          return }
                let occupantJid = XMPPJid(jid: roomJid, resource: jid.username)
                let uploadDomain = XMPPJid(string: self.configuration.uploadDomain)
                let room = self.rooms.first { $0.jid == roomJid } ??
                Room(client: self, room: roomJid, occupant: occupantJid, uploadDomain: uploadDomain, uploadMode: self.configuration.fileUploadMode)
                self.delegate?.queued(client: self, workgroup: workgroup)
                self.rooms.append(room)
                workgroup.on(invite: room, from: roomJid)
                room.add(member: workgroup.jid, role: .workgroup)
                didFindRoom = true
            })
            completion(didFindRoom)
        })
    }
}

// MARK: Roster Entities
protocol RosterPeer {
    func match(jid: XMPPJid) -> Bool
    func on(state: RosterPeerState, for jid: XMPPJid)
    func on(message: XMPPMessage, from: XMPPJid, text: String)
    func on(message: XMPPMessage, state: Room.Message.State, id: String?)
}

public enum RosterPeerState {
    case composing
    case paused
    case active
    case inactive

    init(string: String) {
        switch string {
        case "active":
            self = .active
        case "composing":
            self = .composing
        case "paused":
            self = .paused
        default:
            self = .inactive
        }
    }

    func encode() -> String {
        switch self {
        case .active:
            return "active"
        case .composing:
            return "composing"
        case .paused:
            return "paused"
        default:
            return "inactive"
        }
    }
}

// MARK: Utilities
private extension String {
    var jid: XMPPJid? {
        return XMPPJid(string: self)
    }
}
