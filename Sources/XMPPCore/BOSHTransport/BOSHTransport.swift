// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

class BOSHTransport: XMPPTransport {

    // How often do we poll should probably be a factor of wait...
    private let tollerance = TimeInterval(20)

    private var connection: BOSHConnection

    // MARK: Properties
    private var state = XMPPTransportState.disconnected

    private var jid: XMPPJid!

    private var sessionId: String?

    private var inactivity = TimeInterval(3600)

    private var maxpause = TimeInterval(120)

    private var polling = TimeInterval(20)

    private var wait = TimeInterval(30)

    private var requests = 2

    private var hold = 1

    private var ack = 0

    private var secure = false

    private var authid = ""

    private var rid = randomID()

    private var sendQueue = [XMLParserEl]()

    private let scheduler = BOSHScheduler()

    private var stamp: Date?

    private let loggingDelegate: BOSHTransportLoggingDelegate

    // MARK: API
    weak var delegate: XMPPTransportDelegate?

    init(connection: BOSHConnection = BOSHSessionConnection()) {
        self.connection = connection
        loggingDelegate = BOSHTransportLoggingDelegate()
        self.delegate = loggingDelegate
    }

    func connect(jid: XMPPJid, url: URL) {
        self.jid = jid
        connection.url = url
        state = XMPPTransportState.connecting
        delegate?.on(transport: self, state: state)

        let s = XMPPBody(properties: [
            "xmlns:xmpp": XMPPNamespace.XBOSH.rawValue,
            "xml:lang": "en",
            "content": "text/xml; charset=utf-8",
            "ver": "1.6",
            "xmpp:version": "1.0",
            "ack": String(ack),
            "wait": String(Int(wait)),
            "hold": String(Int(hold)),
            "rid": generateRID(),
            "from": jid.asBare().description,
            "to": jid.domain
        ])

        scheduler.clear()
        scheduler.add(BOSHRequest(body: s, connection: connection, withCompletionHandler: onConnected))
        scheduler.run()

        XMPPLog("BOSHTransport", "CONNECTING TO: \(url.absoluteString)")
    }

    func disconnect() {
        switch state {
        case .connecting:
            state = .disconnected
            delegate?.on(transport: self, state: state)
            scheduler.clear()
        case .connected:
            state = .disconnecting
            delegate?.on(transport: self, state: state)

            let s = XMPPBody(properties: [
                "rid": generateRID(),
                "sid": sessionId!,
                "type": "terminate"
                ])

            scheduler.add(BOSHRequest(body: s, connection: connection, withCompletionHandler: onDisconnected))
            scheduler.run()
        default:
            break
        }
    }

    func restart() {
        let s = XMPPBody(properties: [
            "xmlns:xmpp": XMPPNamespace.XBOSH.rawValue,
            "xmpp:restart": "true",
            "rid": generateRID(),
            "sid": sessionId!
        ])

        scheduler.add(BOSHRequest(body: s, connection: connection, withCompletionHandler: onRestart))
        scheduler.run()
    }

    func send(element: XMLParserEl) {
        if case let .node(name, nil, attrs, children) = element {
            let newElement = XMLParserEl.node(name: name, namespace: .CLIENT,
                                                 attributes: attrs, children: children)
            sendQueue.append(newElement)
        } else {
            sendQueue.append(element)
        }
    }

    func flush() {
        flushSendQueue()
    }

    func complete(completion: @escaping () -> Void) {
        scheduler.complete(completion: completion)
    }

    func processEvents() {
        if shouldPoll() {
            if !sendQueue.isEmpty {
                // Might as well send the queue as a poll
                flushSendQueue()
            } else {
                let s = XMPPBody(properties: [
                    "rid": generateRID(),
                    "sid": sessionId!
                ])
                scheduler.add(BOSHRequest(body: s,
                    connection: connection,
                    withCompletionHandler: onResponse))
            }
        }
        scheduler.run()
    }

    // MARK: Request callbacks
    private func onConnected(_ result: BOSHRequest.Result, request: BOSHRequest) {
        switch result {
        case .error(let error):
            if request.isRecoverable {
                if request.retries == 0 {
                    delegate?.on(transport: self, failure: error)
                }
            } else {
                terminate(error)
            }
        case .empty:
            fatalError("BOSHTransport: Empty response")
        case .result(let body):
            if state == .disconnecting {
                return
            }
            if state != .connecting {
                preconditionFailure("BOSHTransport: Inconsistent state")
            }

            guard body.properties["type"] != "terminate" else {
                XMPPLog("BOSHTransport", "error: received terminate when trying to connect")
                terminate(nil)
                return
            }

            sessionId = body.properties["sid"]
            if let x = body.properties["inactivity"] {
                inactivity = TimeInterval(Int(x)!)
            }
            if let x = body.properties["maxpause"] {
                maxpause = TimeInterval(Int(x)!)
            }
            if let x = body.properties["polling"] {
                polling = TimeInterval(Int(x)!)
            }
            if let x = body.properties["requests"] {
                requests = Int(x)!
            }
            if let x = body.properties["secure"] {
                secure = x == "true"
            }
            if let x = body.properties["authid"] {
                authid = x
            }
            if let x = body.properties["wait"] {
                wait = TimeInterval(Int(x)!)
            }

            connection.setConfiguration(requests, requestTimeout: wait + tollerance, wait: wait + inactivity)
            scheduler.pipes = requests
            scheduler.maxTimeout = inactivity
            sendQueue = []

            XMPPLog("BOSHTransport", "CONNECTION: Requests - \(requests) Inactivity - \(inactivity) Polling - \(polling) Timeout - \(wait + tollerance)")

            state = .connected
            delegate?.on(transport: self, state: state)

            for e in body.elements {
                delegate?.on(transport: self, element: e)
            }

            requestCompleted(request)
        }

    }

    private func onRestart(_ result: BOSHRequest.Result, request: BOSHRequest) {
        switch result {
        case .error(let error):
            if request.isRecoverable {
                if request.retries == 0 {
                    delegate?.on(transport: self, failure: error)
                }
            } else {
                terminate(error)
            }
        case .empty:
            fatalError("BOSHTransport: Empty response")
        case .result(let body):
            for e in body.elements {
                delegate?.on(transport: self, element: e)
            }
        }
        requestCompleted(request)
    }

    // May not be called, as the server is not required to reply
    private func onDisconnected(_ result: BOSHRequest.Result, request: BOSHRequest) {
        switch result {
        case .error:
            break
        case .empty:
            break
        case .result(let body):
            for e in body.elements {
                delegate?.on(transport: self, element: e)
            }
        }
        state = .disconnected
        requestCompleted(request)
    }

    private func onResponse(_ result: BOSHRequest.Result, request: BOSHRequest) {
        switch result {
        case .error(let error):
            if request.isRecoverable {
                if request.retries == 0 {
                    delegate?.on(transport: self, failure: error)
                }
            } else {
                terminate(error)
            }
        case .empty:
            break
        case .result(let body):
            if body.properties["type"] == "terminate" {
                if body.properties["condition"] == "item-not-found" {
                    terminate(XMPPTransportError.timeout)
                } else if body.properties["condition"] != nil {
                    terminate(XMPPTransportError.proto)
                } else {
                    terminate(nil)
                }
                return
            } else if body.properties["type"] == "error" {
                request.fail() // Recoverable error, mark the request as failed
            } else {
                for e in body.elements {
                    delegate?.on(transport: self, element: e)
                }
            }
        }
        requestCompleted(request)
    }

    // MARK: Utilities
    private func terminate(_ err: XMPPTransportError?) {
        scheduler.clear()
        sendQueue = []
        connection.reset()
        if let error = err {
            state = .failed
            delegate?.on(transport: self, state: state)
            delegate?.on(transport: self, error: error)
        } else {
            state = .disconnected
            delegate?.on(transport: self, state: state)
        }
    }

    private func requestCompleted(_ req: BOSHRequest) {
        stamp = Date()
        scheduler.run()
    }

    private func shouldPoll() -> Bool {
        return state == XMPPTransportState.connected && scheduler.shouldPoll(wait)
    }

    private func flushSendQueue() {
        if !sendQueue.isEmpty {
            let s = XMPPBody(
                properties: [
                    "rid": generateRID(),
                    "sid": sessionId!
                ],
                elements: sendQueue
            )
            sendQueue = []
            scheduler.add(BOSHRequest(body: s, connection: connection,
                withCompletionHandler: onResponse))
        }
    }

    private func generateRID() -> String {
        rid += 1
        return String(rid)
    }
}

private func randomID() -> UInt64 {
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
    if SecRandomCopyBytes(kSecRandomDefault, 8, pointer) != 0 {
        fatalError("Failed to randomize uid")
    }
    return UInt64(pointer.pointee) * 49979693
}

// Dummy delegate used for simple logging
private class BOSHTransportLoggingDelegate: XMPPTransportDelegate {
    func on(transport: XMPPTransport, error: XMPPTransportError) {
        XMPPLog("BOSHTransport", "error: \(error)")
    }

    func on(transport: XMPPTransport, failure: XMPPTransportError) {
        XMPPLog("BOSHTransport", "failure: \(failure)")
    }

    func on(transport: XMPPTransport, element: XMLParserEl) {
         XMPPLog("BOSHTransport", "element: \(element)")
    }

    func on(transport: XMPPTransport, state: XMPPTransportState) {
         XMPPLog("BOSHTransport", "state: \(state)")
    }
}
