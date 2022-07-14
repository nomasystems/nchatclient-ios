// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import XMPPCore

protocol RoomDelegate: AnyObject {
    func affiliation(room: Room, for: Room.Occupant)
    func chatstate(room: Room, for: Room.Occupant)
    func chatStatus(room: Room, online: Bool)
    func message(room: Room, message: Room.Message)
    func communicationMessages(communicationId: String?, room: Room, messages: [Room.Message])
    func updateMessageState(room: Room, messageState: Room.Message.State, id: String?)
    func updateMessageInfo(room: Room, message: Room.Message)
}

public class Room {
    weak var client: Client?
    weak var delegate: RoomDelegate?

    let jid: XMPPJid
    let uploadDomainJid: XMPPJid?
    let uploadMode: FileUploadMode
    let occupant: Occupant
    private var workgroup: Occupant?
    private(set) var occupants: [Occupant]
    private var previousCommunicationId: String?
    public var hasPreviousHistory: Bool { previousCommunicationId != nil }

    init(client: Client, room: XMPPJid, occupant: XMPPJid, uploadDomain: XMPPJid?, uploadMode: FileUploadMode = .slot) {
        self.client = client
        self.jid = room
        self.uploadDomainJid = uploadDomain
        self.uploadMode = uploadMode
        self.occupant = Occupant(jid: occupant, role: .user)
        self.occupants = []
    }

    func set(available: Bool, fetchHistory: Bool = true) {
        XMPPLog("ROOM", "send Presence available \(available)")
        let nickedJid = XMPPJid(jid: jid, resource: "client")
        client?.send(presence: XMPPPresence(type: available ? "available": "unavailable", to: nickedJid, data: [
            XMLParserEl.node(name: "x", namespace: .MUC)
        ]))

        XMPPLog("ROOM", "Joining \(jid)")
        if fetchHistory {
            self.fetchHistory()
        }
    }

    func set(state: RosterPeerState) {
        occupant.state = state
        client?.send(message: XMPPMessage(type: "groupchat", to: jid, data: [
            XMLParserEl.node(name: state.encode(), namespace: .CHATSTATE)
        ]))
        XMPPLog("ROOM", "Sending chat state to \(jid) (\(state.encode()))")
    }

    func add(member jid: XMPPJid, role: Occupant.Role) {
        let occupant = Occupant(jid: jid, role: role)
        if role == .workgroup {
            workgroup = occupant
        }
        occupants.append(occupant)
    }

    func leave() {
        guard let clientJid = client?.jid else { return }
        let id = UUID().uuidString
        let iq = XMPPIq(type: .set, id: id, to: jid, data: [
            XMLParserEl.node(name: "query", namespace: .MUC_ADMIN, children: [
                XMLParserEl.node(name: "item", attributes: [
                    "affiliation": "none",
                    "jid": clientJid.asBare().description
                ])
            ])
        ])
        client?.send(iq: iq, completion: {_ in })
        XMPPLog("ROOM", "Leaving \(jid)")
    }

    func send(satisfaction: Int, completion: @escaping (XMPPIq) -> Void) {
        guard let workgroupJid = workgroup?.jid, let client = client else {
            completion(XMPPIq(type: .error, id: "satisfaction-error"))
            return
        }
        let satisfactionIq = XMPPIq(type: .set, id: "satisfaction-set-1", to: workgroupJid, data: [
            XMLParserEl.node(name: "satisfaction", namespace: .WORKGROUP,
                                attributes: ["value": String(satisfaction),
                                             "jid": jid.description])
        ])
        client.send(iq: satisfactionIq, completion: completion)
        XMPPLog("ROOM", "Sent satisfaction \(satisfactionIq)")
    }

    public func sendRead(message: Message) {
        let read = XMLParserEl.node(name: "read", attributes: ["id": message.id])
        client?.send(message: XMPPMessage(type: "groupchat", to: jid, data: [read]))

        XMPPLog("ROOM", "Sending read to \(jid) ")
    }

    func requestSlot(message: Message, compressTo bytes: Int? = nil) {
        guard let attachmentData = message.attachment?.data, uploadMode == .slot else {
            delegate?.updateMessageState(room: self, messageState: .error(.upload), id: message.id)
            return
        }

        var filename = "\(message.id)"
        filename.append(message.attachment?.pathExtension ?? "")

        let iq = XMPPIq(type: .get, id: message.id, from: client?.jid, to: uploadDomainJid, data: [
            XMLParserEl.node(name: "request", namespace: .SLOT_REQUEST, attributes: [
                "filename": filename,
                "size": "\(attachmentData.count)"
            ])
        ])
        client?.send(iq: iq) { result in
            switch result.type {
            case .result:
                for x in result.data {
                    guard case let .node("slot", .SLOT_REQUEST, _, children) = x else { continue }
                    let format =  self.getFileContentType(format: message.attachment?.pathExtension ?? "")
                    self.upload(data: attachmentData, filename: filename,
                                fileContentType: format, items: children) { result, error in
                        guard error == nil else {
                            XMPPLog("ROOM", "Error")
                            self.delegate?.updateMessageState(room: self, messageState: .error(.upload), id: message.id)
                            return
                        }
                        guard let getUrl = result else {
                            XMPPLog("ROOM", "Error")
                            self.delegate?.updateMessageState(room: self, messageState: .error(.upload), id: message.id)
                            return
                        }
                        let rbodyContent: String
                        let jsonObject = ["getUrl": getUrl,
                                          "filename": filename]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            rbodyContent = jsonString
                        } else {
                            rbodyContent = "{\"getUrl\":\"\(getUrl)\",\"filename\":\"\(filename)\"}"
                        }

                        var rbody = [XMLParserEl]()
                        var data = [XMLParserEl]()
                        if !message.text.isEmpty {
                            var body = [XMLParserEl]()
                            body.append(XMLParserEl.text(message.text))
                            data.append(XMLParserEl.node(name: "body", children: body))
                        }

                        rbody.append(XMLParserEl.text(rbodyContent))
                        data.append(XMLParserEl.node(name: "rbody", children: rbody))
                        data.append(XMLParserEl.node(name: "receipts"))

                        let xmppMessage = XMPPMessage(type: "groupchat", id: message.id, to: self.jid, data: data)

                        self.client?.send(message: xmppMessage)
                        message.state = .pending
                        self.on(message: xmppMessage, state: message.state, id: message.id)
                        XMPPLog("ROOM", "Sending message to \(self.jid) (\(message.id)")
                    }
                }

            case .error:
                XMPPLog("ROOM", "ERROR")
                var compress: Int?
                for x in result.data {
                    guard case let .node("error", _, _, children) = x else {
                        continue
                    }
                    message.state = .error(.upload)
                    children.forEach { parent in
                        if case let .node("file-too-large", _, _, childrenF) = parent {
                            message.state = .error(.uploadFileTooLarge)
                            childrenF.forEach { option in
                                if case .node("max-file-size", _, _, _) = option {
                                    compress = Int(option.getText())
                                }
                            }
                        }
                    }
                }

                if let compress = compress {
                    self.requestSlot(message: message, compressTo: compress)
                } else {
                    self.delegate?.updateMessageState(room: self, messageState: message.state, id: message.id)
                }

            default:
                break
            }
        }
    }

    func send(message: Message) {
        var data = [XMLParserEl]()
        var body = [XMLParserEl]()
        var rbody = [XMLParserEl]()

        if let attachment = message.attachment, uploadMode == .raw {
            append(attachment: attachment, to: &body, and: &data)
        }

        if !message.text.isEmpty {
            body.append(XMLParserEl.text(message.text))
        }

        if let metadata = message.metadata {
            rbody.append(XMLParserEl.text(metadata))
        }

        data.append(XMLParserEl.node(name: "rbody", children: rbody))
        data.append(XMLParserEl.node(name: "body", children: body))
        data.append(XMLParserEl.node(name: "receipts"))

        let xmppMessage = XMPPMessage(type: "groupchat", id: message.id, to: jid, data: data)

        client?.send(message: xmppMessage)
        message.state = .pending
        on(message: xmppMessage, state: message.state, id: message.id)

        XMPPLog("ROOM", "Sending message to \(jid) (\(message.id))")
    }

    func updateMetadata(userData: ChatUserData, completion: @escaping (XMPPIq) -> Void) {
        guard let workgroupJid = workgroup?.jid else { return }
        guard let contactJid = client?.jid else { return }

        let to = XMPPJid(jid: workgroupJid, resource: contactJid.username)

        let crm = userData.crmXmlMetadata(contactJid: contactJid)
        let iq = XMPPIq(type: .set, id: "update-metadata-1", to: to, data: [
            XMLParserEl.node(name: "communication-metadata", namespace: .WORKGROUP,
                             children: [crm])
        ])

        client?.send(iq: iq) { result in
            completion(result)
        }
        XMPPLog("ROOM", "Updating metadata")
    }

    /// Appends attachment in base64 format to message body.
    func append(attachment: ChatAttachment, to body: inout [XMLParserEl], and data: inout [XMLParserEl]) {
        if let title = attachment.title {
            body.append(XMLParserEl.text(title))
            body.append(XMLParserEl.text("\n"))
        }

        if let url = attachment.url {
            body.append(XMLParserEl.text(url.absoluteString))
            body.append(XMLParserEl.text("\n"))
        }

        let encodedAttachment = "data:image/png;base64," + attachment.data.base64EncodedString()
        data.append(XMLParserEl.node(name: "thumbnail", children: [
            XMLParserEl.text(encodedAttachment)
        ]))

        XMPPLog("ROOM", "Sending attachment to \(jid) sized: \(encodedAttachment.lengthOfBytes(using: .utf8))")
    }

    func on(affiliation: Room.Occupant.Affiliation, for jid: XMPPJid, status: String) {
        if jid == occupant.jid {
            XMPPLog("ROOM", "Update occupant: \(jid) - \(occupant.role) (\(affiliation))")
            occupant.affiliation = affiliation
            delegate?.affiliation(room: self, for: occupant)
        } else if let o = occupants.first(where: {$0.jid == jid}) {
            XMPPLog("ROOM", "Update occupant: \(jid) - \(o.role) (\(affiliation))")
            o.affiliation = affiliation
            delegate?.affiliation(room: self, for: o)
            if affiliation == .member {
                delegate?.chatStatus(room: self, online: status != "unavailable")
            }
        } else {
            // NOTE: This is a hack
            let t: Occupant.Role = affiliation == .owner ? .workgroup : .agent
            XMPPLog("ROOM", "Added occupant: \(jid) - \(t) (\(affiliation))")

            let o = Room.Occupant(jid: jid, role: t, affiliation: affiliation)
            occupants.append(o)
            delegate?.affiliation(room: self, for: o)
        }
    }

    public func fetchHistory() {
        fetchCommunication()
    }

    func fetchCommunication() {
        guard let previousCommunicationId = previousCommunicationId else {
            fetchCommunication(communicationId: "most_recent")
            return
        }

        fetchCommunication(communicationId: previousCommunicationId)
    }

    func fetchCommunication(communicationId: String) {
        XMPPLog("ROOM", "Fetching messages from \(communicationId) for \(jid.asBare())")

        let iq = XMPPIq(type: .get, id: "room-messages-history", data: [
            XMLParserEl.node(name: "query", namespace: .MESSAGES, children: [
                XMLParserEl.node(name: "item", attributes: [
                    "peer": jid.asBare().description,
                    "communication": communicationId
                ])
            ])
        ])

        client?.send(iq: iq) { result in
            switch result.type {
            case .result:
                for x in result.data {
                    if case let .node("query", .MESSAGES, attrs, children) = x {
                        if let prevCommunicationId = attrs["previousCommunication"], prevCommunicationId != "undefined" {
                            self.previousCommunicationId = prevCommunicationId
                        } else {
                            self.previousCommunicationId = nil
                        }
                        let msgs = children.compactMap(self.historyMessage)
                        self.delegate?.communicationMessages(communicationId: self.previousCommunicationId,
                                                             room: self,
                                                             messages: msgs)
                    }
                }
            default:
                self.previousCommunicationId = communicationId
                break
            }
        }
    }

    // MARK: Room Model
    public class Occupant {
        let jid: XMPPJid
        let role: Role
        var affiliation: Affiliation
        var state: RosterPeerState

        init(jid: XMPPJid, role: Role, affiliation: Affiliation) {
            self.jid = jid
            self.role = role
            self.affiliation = affiliation
            self.state = .active
        }

        convenience init(jid: XMPPJid, role: Role) {
            self.init(jid: jid, role: role, affiliation: .none)
        }

        public enum Affiliation {
            case owner
            case admin
            case member
            case outcast
            case none

            init(string: String) {
                switch string {
                case "owner":
                    self = .owner
                case "admin":
                    self = .admin
                case "member":
                    self = .member
                case "outcast":
                    self = .outcast
                default:
                    self = .none
                }
            }
        }

        public enum Role {
            case workgroup
            case agent
            case user
        }
    }

    public class Message: Equatable {
        let id: String
        public var state: State
        public let text: String
        public let from: Occupant.Role
        public let attachment: ChatAttachment?
        public let timestamp: Date
        public let metadata: String?
        public let rawAttachment: String?

        init(id: String,
             state: State,
             text: String,
             from: Occupant.Role,
             attachment: ChatAttachment? = nil,
             timestamp: Date? = Date(),
             metadata: String? = nil,
             rawAttachment: String? = nil) {
            self.id = id
            self.state = state
            self.text = text
            self.from = from
            self.attachment = attachment
            self.timestamp = timestamp ?? Date()
            self.metadata = metadata
            self.rawAttachment = rawAttachment
        }

        public enum State: Equatable {
            case pending
            case sent
            case delivered
            case read
            case error(ErrorType)

            public enum ErrorType {
                case upload
                case uploadFileTooLarge
            }
        }

        public static func == (lhs: Message, rhs: Message) -> Bool {
            lhs.id == rhs.id &&
            lhs.text == rhs.text &&
            lhs.timestamp == rhs.timestamp
        }
    }
}

extension Room: RosterPeer {
    func match(jid: XMPPJid) -> Bool {
        return self.jid == jid.asBare()
    }

    func on(state: RosterPeerState, for jid: XMPPJid) {
        XMPPLog("ROOM", "Chat state from \(jid)")
        if let o = occupants.first(where: {$0.jid == jid}) {
            o.state = state
            delegate?.chatstate(room: self, for: o)
        }
    }

    func on(message: XMPPMessage, from: XMPPJid, text: String) {
        XMPPLog("ROOM", "Message from \(from)")
        let rbodyText: String? = message.data.compactMap {
            guard case .node("rbody", _, _, _) = $0 else { return nil }
            return $0.getText()
        }.first
        let attachment: ChatAttachment? = {
            guard uploadMode == .raw else { return nil }
            for element in message.data {
                if case .node("thumbnail", _, _, _) = element,
                   let data = Data(base64Encoded: element.getText()) {
                    return ChatAttachment(data: data)
                }
            }
            return nil
        }()
        let role: Occupant.Role = workgroup?.jid.username == from.resource ? .workgroup : .agent
        let msg = Message(id: message.id,
                          state: .delivered,
                          text: text,
                          from: role,
                          attachment: attachment,
                          metadata: rbodyText)
        downloadFromJsonInfoAndDelegate(jsonInfo: rbodyText, msg: msg, isNewMessage: true)
    }

    func on(message: XMPPMessage, state: Message.State, id: String?) {
        delegate?.updateMessageState(room: self, messageState: state, id: id)
    }
}

private extension Room {
    func buildMessageAndDelegate(msg: Message, isNewMessage: Bool, attachment: ChatAttachment? = nil) {
        let msgToSend: Message
        if let attachment = attachment {
            msgToSend = Message(id: msg.id, state: msg.state, text: msg.text, from: msg.from,
                                attachment: attachment, timestamp: msg.timestamp)
        } else {
            msgToSend = msg
        }
        if isNewMessage {
            delegate?.message(room: self, message: msgToSend)
        } else {
            delegate?.updateMessageInfo(room: self, message: msgToSend)
        }
    }

    func downloadData(url: URL, saveFile: URL? = nil, completion: @escaping (Data?) -> Void) {
        getData(from: url) { data, _, error in
            guard let data = data,
                  error == nil else {
                      completion(nil)
                      return
                  }
            DispatchQueue.main.sync {
                if let path = saveFile?.path {
                    FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
                }
                completion(data)
            }
        }
    }

    func downloadFileData(from url: URL, completionHandler: @escaping (Data?) -> Void) {
        let directory = NSTemporaryDirectory()
        let fileName = url.lastPathComponent
        if let fileURL = NSURL.fileURL(withPathComponents: [directory, fileName]) {
            if !FileManager.default.fileExists(atPath: fileURL.absoluteString) {
                downloadData(url: url, saveFile: fileURL, completion: completionHandler)
            } else {
                let data = try? Data(contentsOf: fileURL)
                completionHandler(data)
            }
        } else {
            downloadData(url: url, completion: completionHandler)
        }
    }

    func downloadFromJsonInfoAndDelegate(jsonInfo: String?, msg: Message, isNewMessage: Bool) {
        if let rbodyText = jsonInfo,
           let data = rbodyText.data(using: .utf8),
           let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let getUrl = jsonDict["getUrl"],
           let filename = jsonDict["filename"] as NSString?,
           let url = URL(string: getUrl) {
            XMPPLog("ROOM", "rbody found: \(rbodyText)")

            downloadFileData(from: url) { result in
                let attachment = result.flatMap {
                    ChatAttachment(data: $0, pathExtension: filename.pathExtension)
                }
                self.buildMessageAndDelegate(msg: msg, isNewMessage: isNewMessage, attachment: attachment)
            }
        } else {
            buildMessageAndDelegate(msg: msg, isNewMessage: isNewMessage)
        }
    }

    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }

    func getFileContentType(format: String) -> String {
        if format.contains("pdf") {
            return "application/pdf"
        }
        return "image/jpeg"
    }

    func historyMessage(item: XMLParserEl) -> Message? {
        guard case let .node("item", _, _, children) = item else { return nil }
        var _from: XMPPJid?
        var _body: String?
        var _metadata: String?
        var attachmentInBase64: String?
        var _time: Date?
        var read = false
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"

        for x in children {
            if case .node("from", _, _, _) = x {
                _from = XMPPJid(string: x.getText())
            } else if case .node("body", _, _, _) = x {
                _body = x.getText()
            } else if case .node("metadata", _, _, _) = x {
                _metadata = x.getText()
            } else if case .node("attachment", _, _, _) = x, uploadMode == .raw {
                attachmentInBase64 = x.getText()
            } else if case .node("time", _, _, _) = x {
                _time = dateFormatter.date(from: x.getText())
            } else if case .node("isRead", _, _, _) = x {
                read = NSString(string: x.getText()).boolValue
            }
        }

        guard let from = _from, let body = _body else {
            return nil
        }

        let role: Occupant.Role = workgroup?.jid == from ? .workgroup :
        client?.jid == from ? .user : .agent
        let msg = Message(id: UUID().uuidString,
                          state: read ? .read : .delivered,
                          text: body,
                          from: role,
                          timestamp: _time,
                          metadata: _metadata,
                          rawAttachment: attachmentInBase64)

        if let metadata = _metadata, !metadata.isEmpty {
            downloadFromJsonInfoAndDelegate(jsonInfo: metadata, msg: msg, isNewMessage: false)
        }

        return msg
    }

    func upload(data: Data, filename: String, fileContentType: String, items: [XMLParserEl], completionHandler: @escaping (String?, Error?) -> Void) {
        var put: String?
        var get: String?

        items.forEach { parent in
            if case let .node("put", _, children, _) = parent,
               let child = children.first(where: { $0.key == "url" }) {
                put = child.value
            } else if case let .node("get", _, children, _) = parent,
                      let child = children.first(where: { $0.key == "url" }) {
                get = child.value
            }
        }

        guard let getUrl = get, let putUrlString = put,
              let putUrl = URL(string: putUrlString) else {
                  enum UrlError: Error { case emptyUrl }
                  completionHandler(nil, UrlError.emptyUrl)
                  return
              }

        let session = URLSession(configuration: URLSessionConfiguration.default)
        var mutableURLRequest = URLRequest(url: putUrl)
        mutableURLRequest.httpMethod = "PUT"

        let boundaryConstant = "----------------12345"
        let contentType = "multipart/form-data;boundary=" + boundaryConstant
        mutableURLRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // create upload data to send
        let dataToAppend = ["\r\n--\(boundaryConstant)\r\n".data(using: .utf8),
                            "Content-Disposition: form-data; name=\"picture\"; filename=\"\(filename)\"\r\n".data(using: .utf8),
                            "Content-Type: \(fileContentType)\r\n\r\n".data(using: .utf8),
                            data,
                            "\r\n--\(boundaryConstant)--\r\n".data(using: .utf8)]

        do {
            enum UploadError: Error { case dataEncoding }
            var uploadData = Data()
            try dataToAppend.forEach { optionalData in
                guard let data = optionalData else { throw UploadError.dataEncoding }
                uploadData.append(data)
            }
            mutableURLRequest.httpBody = uploadData
        } catch let error {
            completionHandler(nil, error)
            return
        }

        session.dataTask(with: mutableURLRequest, completionHandler: { _, _, error in
            completionHandler(getUrl, error)
        }).resume()
    }
}
