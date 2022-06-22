// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

public enum AuthenticationMethod {
    case plain
    case custom(name: String)
}

public enum AuthenticationResponse {
    case accept(jid: String?, credential: String?) // Defaults to a random user did if one is not provided
    case skip // Skips authentication with this particular method. If all are skipped, PLAIN authentication with a random userJid is used, if possible.
    case abort // Aborts the whole authentication process, resulting in a failure to connect.
}

public protocol XMPPClientAuthenticationDelegate: AnyObject {
    func xmppClient(_ client: XMPPClientBase,
                    didReceiveAuthenticationMethod method: AuthenticationMethod,
                    completionHandler: @escaping (AuthenticationResponse) -> Void
    )
}

open class XMPPClientBase: XMPPTransportDelegate {
    // JID - possibly bound
    public private(set) var jid: XMPPJid?

    // Authentication delegate. Supports authentication with PLAIN or custom authentication methods.
    public weak var authenticationDelegate: XMPPClientAuthenticationDelegate?

    // Defaults to BOSHTransport
    private var transport: XMPPTransport

    // Current protocol state
    private var currentState: XMPPProtocolState {
        didSet {
            on(state: currentState, previous: oldValue)
        }
    }

    // Available authentication mechanisms
    public struct Mechanism {
        public static let plain = "PLAIN"
    }
    public var plainDefaultCredentials: (username: String, password: String) = ("", "")
    private var mechanisms: [String] = []

    // True if the server require a chat session
    private var sessionRequired = false

    // Handle iq responses
    private var iqCompletions: [String: (XMPPIq) -> Void] = [:]

    public init() {
        self.transport = BOSHTransport()
        self.currentState = .terminated
        self.transport.delegate = self
    }

    // Connect to the server
    open func connect(url: URL, jid: XMPPJid) -> Bool {
        if currentState == .terminated {
            self.jid = jid
            self.currentState = .connecting
            transport.connect(jid: jid, url: url)
            return true
        } else {
            error(internal: .state)
            return false
        }
    }

    open func disconnect(completion: (() -> Void)? = nil) {
        guard currentState != .terminated, currentState != .terminated else { return }
        transport.disconnect()
        if let completion = completion {
            transport.complete(completion: completion)
        }
    }

    open func send(iq: XMPPIq, completion: @escaping (XMPPIq) -> Void) {
        iqCompletions[iq.id] = completion
        transport.send(element: iq.encode())
        transport.flush()
    }

    open func send(presence: XMPPPresence) {
        transport.send(element: presence.encode())
        transport.flush()
    }

    open func send(message: XMPPMessage) {
        transport.send(element: message.encode())
        transport.flush()
    }

    open func processEvents() {
        transport.processEvents()
    }

    // MARK: XMPPTransportDelegate methods
    func on(transport: XMPPTransport, error err: XMPPTransportError) {
        error(transport: err)
    }

    func on(transport: XMPPTransport, failure: XMPPTransportError) {
        // XMPPLog("XMPPClient failure: \(failure)")
    }

    func on(transport: XMPPTransport, element: XMLParserEl) {
        guard case let .node(_, namespace?, _, _) = element else { return }
        switch namespace {
        case .STREAM:
            handle(stream: element)
        case .SASL:
            handle(sasl: element)
        case .CLIENT:
            handle(client: element)
        default:
            XMPPLog("XMPPClient", "unknown element: \(element)")
        }
    }

    func on(transport: XMPPTransport, state: XMPPTransportState) {
        XMPPLog("STATE", "\(state)")
        switch state {
        case .disconnecting:
            currentState = .terminating
        case .disconnected:
            currentState = .terminated
        default:
            break
        }
    }

    // MARK: STREAM
    private func handle(stream element: XMLParserEl) {
        switch element {
        case .node("error", _, _, _):
            handle(error: element)
        case .node("features", _, _, _):
            handle(features: element)
        default:
            XMPPLog("STREAM", "Unknown directive \(element)")
        }
    }

    private func handle(error element: XMLParserEl) {
        guard case let .node(name, _, _, _) = element else { return }
        error(protocol: .stream(name))
    }

    private func handle(features element: XMLParserEl) {
        element.forEachElement { feature in
            switch feature {
            case .node(_, .SASL, _, _):
                handle(sasl: feature)
            case .node(_, .BIND, _, _):
                handle(bind: feature)
            case .node(_, .SESSION, _, _):
                handle(session: feature)
            default:
                XMPPLog("FEATURE", "Unknown feature: \(feature)")
            }
        }
    }

    // MARK: SASL
    private func handle(sasl element: XMLParserEl) {
        switch element {
        case .node("success", _, _, _):
            on(authenticated: true)
        case .node("failure", _, _, _):
            on(authenticated: false)
        case .node("mechanisms", _, _, _):
            handle(saslMechanisms: element)
        default:
            XMPPLog("SASL", "Unknown directive \(element)")
        }
    }

    private func handle(saslMechanisms element: XMLParserEl) {
        guard case let .node(_, _, _, children) = element else { return }
        mechanisms = children.compactMap {
            guard case .node("mechanism", .SASL, _, _) = $0 else { return nil }
            return $0.getText()
        }
        guard !mechanisms.isEmpty else {
            XMPPLog("SASL", "No available authentication mechanisms.")
            return
        }

        // Mechanisms are offered in the same order as they arrive...
        // ... except for PLAIN, which has the lowest priority. If offered, we place it at the end of the list.
        if let plainMechanismIndex = mechanisms.firstIndex(where: { $0 == Mechanism.plain }),
           mechanisms.last != Mechanism.plain {
            mechanisms.swapAt(plainMechanismIndex, mechanisms.count - 1)
        }

        if let mechanism = mechanisms.first {
            requestAuthentication(for: mechanism)
        }
    }

    private func requestAuthentication(for mechanism: String) {
        let method: AuthenticationMethod = mechanism == Mechanism.plain ? .plain : .custom(name: mechanism)
        authenticationDelegate?.xmppClient(self, didReceiveAuthenticationMethod: method) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .accept(let jid, let credential):
                if case .plain = method {
                    let username = jid ?? self.plainDefaultCredentials.username
                    let password = credential ?? self.plainDefaultCredentials.password
                    if let jidUsername = XMPPJid(string: username)?.username,
                       let auth = self.basicAuth(username: jidUsername, password: password) {
                        self.sendAuthRequest(auth: auth, mechanism: mechanism)
                    } else {
                        XMPPLog("SASL", "Could not generate a valid basic auth")
                    }
                } else if jid != nil, let credential = credential {
                    self.sendAuthRequest(auth: credential, mechanism: mechanism)
                } else {
                    fallthrough // Try with following mechanism in the queue.
                }
            case .skip:
                self.mechanisms.removeFirst()
                if let mechanism = self.mechanisms.first {
                    self.requestAuthentication(for: mechanism)
                } else {
                    fallthrough // Ran out of offered mechanisms -> abort.
                }
            case .abort:
                XMPPLog("SASL", "No supported mechanism: \(mechanism)")
            }
        }
    }

    private func basicAuth(username: String, password: String) -> String? {
        let auth = "\0" + username + "\0" + password
        return auth.data(using: .utf8)?.base64EncodedString()
    }

    private func sendAuthRequest(auth: String, mechanism: String) {
        transport.send(element: XMLParserEl.node(
            name: "auth",
            namespace: .SASL,
            attributes: ["mechanism": mechanism],
            children: [XMLParserEl.text(auth)]
        ))
    }

    open func on(authenticated: Bool) {
        if authenticated {
            transport.restart()
        } else {
            error(protocol: .authentication)
        }
    }

    // MARK: BIND
    private func handle(bind element: XMLParserEl) {
        switch element {
        case .node("bind", _, _, _):
            sendBindRequest()
        default:
            XMPPLog("BIND", "Unknown directive \(element)")
        }
    }

    private func sendBindRequest() {
        guard let jid = jid else {
            XMPPLog("BIND", "Trying to bind without a valid jid")
            return
        }
        let iq = XMPPIq(type: .set, id: "bind", data: [
            XMLParserEl.node(name: "bind", namespace: .BIND, children: [
                XMLParserEl.node(name: "resource", children: [
                    XMLParserEl.text(jid.resource)
                ])
            ])
        ])

        send(iq: iq) { result in
            self.on(bind: result)
        }
    }

    private func jid(from elements: [XMLParserEl]) -> XMPPJid? {
        guard !elements.isEmpty else { return nil }
        let bind = elements.first { element in
            guard case .node("jid", .BIND, _, _) = element else { return false }
            return true
        }
        if let jidString = bind?.getText(), let jid = XMPPJid(string: jidString) {
            return jid
        }
        return jid(from: elements.flatMap { element -> [XMLParserEl] in
            guard case let .node(_, _, _, children) = element else { return [] }
            return children
        })
    }

    private func on(bind result: XMPPIq) {
        switch result.type {
        case .error:
            error(protocol: .bind)
        case .result:
            if let newJid = jid(from: result.data) {
                jid = newJid
            }
            if sessionRequired {
                sendSessionRequest()
            } else {
                currentState = .active
            }
        default:
            fatalError("IQ is not a response type")
        }
    }

    // MARK: SESSION
    private func handle(session element: XMLParserEl) {
        if case .node("session", _, _, _) = element {
            sessionRequired = true
        } else {
            XMPPLog("SESSION", "Unknown directive \(element)")
        }
    }

    private func sendSessionRequest() {
        let iq = XMPPIq(type: .set, id: "session", data: [
            XMLParserEl.node(name: "session", namespace: .SESSION)
        ])

        self.send(iq: iq) { result in
            self.on(session: result)
        }
    }

    private func on(session result: XMPPIq) {
        switch result.type {
        case .error:
            error(protocol: .session)
        case .result:
            XMPPLog("SESSION", "Started")
            currentState = .active
        default:
            fatalError("IQ is not a response type")
        }
    }

    // MARK: CLIENT
    private func handle(client element: XMLParserEl) {
        switch element {
        case .node("iq", _, _, _):
            handle(iq: element)
        case .node("presence", _, _, _):
            handle(presence: element)
        case .node("message", _, _, _):
            handle(message: element)
        default:
            XMPPLog("CLIENT", "Unknown directive \(element)")
        }
    }

    private func handle(iq element: XMLParserEl) {
        guard let iq = XMPPIq(from: element) else { return }
        if iq.type == .result || iq.type == .error,
            let completion = iqCompletions.removeValue(forKey: iq.id) {
            completion(iq)
        }
    }

    private func handle(presence element: XMLParserEl) {
        guard let presence = XMPPPresence(from: element) else { return }
        on(presence: presence)
    }

    private func handle(message element: XMLParserEl) {
        guard let message = XMPPMessage(from: element) else { return }
        on(message: message)
    }

    // MARK: ERROR
    open func error(internal error: XMPPInternalError) {
        switch error {
        case .state:
            fatalError("XMPP: Inconsistent state: \(currentState)")
        case .workgroup:
            break
        }
    }

    open func error(transport error: XMPPTransportError) {
        XMPPLog("ERROR Transport", "\(error)")
        currentState = .failed
        transport.disconnect()
    }

    open func error(protocol error: XMPPProtocolError) {
        XMPPLog("ERROR Protocol", "\(error)")
        currentState = .failed
        transport.disconnect()
    }

    // MARK: Default event handlers
    open func on(state: XMPPProtocolState, previous: XMPPProtocolState) {
    }

    open func on(presence: XMPPPresence) {
    }

    open func on(message: XMPPMessage) {
    }
}
