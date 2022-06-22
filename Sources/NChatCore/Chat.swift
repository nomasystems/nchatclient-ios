// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation
import os
import XMPPCore
import UIKit

/// Additional authentication mechanisms that consumer can include optionally.
///
/// If any additional mechanisms are indicated, they are prioritized over 'PLAIN' authentication mechanism in the same order they are specified inside the list.
public protocol ChatAuthenticationDelegate: AnyObject {
    func chat(_ chat: Chat,
              didReceiveAuthenticationMethod method: AuthenticationMethod,
              completionHandler: @escaping (AuthenticationResponse) -> Void
    )
}

public protocol ChatDelegate: AnyObject {
    func onState(_ state: ChatState)
    func onStatus(online: Bool)
    func onAgentChatState(_ state: Chat.AgentState?)
}

public protocol ChatMessagesDelegate: AnyObject {
    func onHistoryMessages(_ message: [Room.Message], communicationId: String?)
    func onMessageStateUpdate(_ message: Room.Message)
    func onNewMessage(_ message: Room.Message)
    func onUpdatedMessages()
    func onRemovedMessage(_ message: Room.Message)
    func onSystemMessage(_ message: SystemMessage)
    func onResendMessage(_ message: Room.Message, _ sender: Any?)
}

open class Chat {
    // MARK: - Public API
    /// Names used by the chat when issuing notifications to the default `NotificationCenter`.
    ///
    /// All notifications as posted with the chat object as sender.
    public enum Notifications {
        /// The chat received a new incoming message.
        public static let incomingMessage = Notification.Name("com.nomasystems.nmachatcoreui.incomingMessage")
        /// The chat changed its state. See `ChatState`.
        public static let stateTransition = Notification.Name("com.nomasystems.nmachatcoreui.stateTransition")
    }

    /// Defines the parameters to setup a chat connection.
    public let configuration: ChatConfiguration

    /// Returns the current state of the chat.
    public private(set) var state: ChatState = .initialized {
        didSet {
            notifyStateObservers()
            delegate?.onState(state)

            if (state == .closing || state == .closed) && backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    }

    /// Returns the last message received in the chat; doesn't include the user's own messages.
    public var lastMessage: ChatMessage? {
        if let msg = messages.reversed().first(where: { $0.from != .user }) {
            return ChatMessage(text: msg.text, timestamp: msg.timestamp)
        }
        return nil
    }

    /// Returns the total number of messages since the user's last message.
    public var numberOfUnansweredMessages: Int {
        if let lastUserMessageIndex = messages.reversed().firstIndex(where: { $0.from == .user }) {
            return messages.count - lastUserMessageIndex.base
        } else {
            return messages.count
        }
    }

    /// Returns the total number of unread messages .
    public var numberOfUnreadMessages: Int {
        let unreadMessages = messages.filter({ $0.from == .agent && $0.state != .read })
        return unreadMessages.count
    }

    /**
     Creates a chat with the specified chat configuration.

     - Parameter configuration: A configuration object that specifies the particular server and queue to connect,
     as well as the particular user data.
     */
    public init(configuration: ChatConfiguration) {
        self.configuration = configuration
        client = Client(configuration: configuration)

        let dns = NotificationCenter.default
        dns.addObserver(self,
                        selector: #selector(applicationDidEnterBackground(_:)),
                        name: UIApplication.didEnterBackgroundNotification,
                        object: nil)
        dns.addObserver(self,
                        selector: #selector(applicationWillEnterForeground(_:)),
                        name: UIApplication.willEnterForegroundNotification,
                        object: nil)
        client.delegate = self
        client.authenticationDelegate = self
    }

    /**
     Public close chat function
     */
    public func closeChat(leave leavePermanently: Bool = true) {
        if leavePermanently {
            self.close()
        } else {
            self.state = .closed
            self.client.disconnect(leavePermanently: false)
        }
        self.reset()
    }

    public func queue() {
        state = .pending
        systemMessage = SystemMessage(type: .pendingStatus)
        client.connect()
    }

    /**
     Public send satisfaction function
     */
    public func sendSatisfaction(satisfaction: Int?, completion: @escaping (XMPPIq?) -> Void) {
        guard let satisfaction = satisfaction, let room = room,
              ![.closing, .closed, .error].contains(state) else {
                  completion(nil)
                  return
              }
        room.send(satisfaction: satisfaction, completion: completion)
    }

    // Send a groupchat message
    public func send(message text: String,
                     attachment: ChatAttachment? = nil,
                     metadata: String? = nil,
                     state: Room.Message.State = .pending) {
        guard let room = room else {
            os_log("Sending a message to a non-joined room", log: errorLog)
            return
        }
        let msg = Room.Message(
            id: UUID().uuidString,
            state: state,
            text: text,
            from: room.occupant.role,
            attachment: attachment,
            metadata: metadata
        )
        append(message: msg, notify: true)
        if attachment != nil {
            switch configuration.fileUploadMode {
            case .raw:
                room.send(message: msg)
            case .slot:
                room.requestSlot(message: msg)
            }
        } else {
            room.send(message: msg)
        }
    }

    // Send a message already sent
    public func send(message: Room.Message) {
        guard let room = room else {
            os_log("Sending a message already sent", log: errorLog)
            return
        }
        messages.removeAll(where: { $0 == message })
        messages.append(message)
        messagesDelegate?.onUpdatedMessages()
        if message.attachment != nil {
            room.requestSlot(message: message)
        } else {
            room.send(message: message)
        }
    }

    // Sets the current chat state
    public func set(peerState state: RosterPeerState) {
        room?.set(state: state)
    }

    // MARK: - Internal API properties
    public struct AgentState {
        public let state: RosterPeerState
        let timestamp: Date
    }

    private var client: Client
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let errorLog = OSLog(subsystem: "com.nomasystems.nmachatcoreui",
                                 category: "Error")
    public weak var delegate: ChatDelegate?
    public weak var messagesDelegate: ChatMessagesDelegate?
    public weak var authenticationDelegate: ChatAuthenticationDelegate?
    private(set) public weak var room: Room?
    public var userInput: String = ""

    // A fifo of messages sent and received
    private(set) public var messages: [Room.Message] = []

    // The last system generated message
    private(set) public var systemMessage: SystemMessage? {
        didSet {
            if let message = systemMessage {
                messagesDelegate?.onSystemMessage(message)
            }
        }
    }

    // The agent state if available, see Chat State XEP
    var agentChatState: AgentState? {
        didSet {
            delegate?.onAgentChatState(agentChatState)
        }
    }

    // Randomly generated JID. Useful for restoring previous anonymous chat sessions.
    public var randomlyGeneratedJID: String? {
        client.randomlyGeneratedJID
    }
}

extension Chat {
    // MARK: - Observer callbacks
    @objc func applicationDidEnterBackground(_ notification: AnyObject) {
        guard state != .initialized, state != .closed else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.backgroundTask != .invalid else { return }
            let taskId = strongSelf.backgroundTask
            strongSelf.backgroundTask = .invalid
            strongSelf.close(leavePermanently: false) {
                strongSelf.systemMessage = SystemMessage(type: .closedInactivity)
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }

    @objc func applicationWillEnterForeground(_ notification: AnyObject) {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        room?.set(available: true, fetchHistory: false)
    }

    func close(forced: Bool = false) {
        guard state != .initialized && state != .closed && state != .error else {
            return
        }

        if forced {
            state = .closed
        }

        client.disconnect(leavePermanently: true)
    }

    func close(leavePermanently: Bool = true, completion: @escaping () -> Void) {
        state = .closed
        client.disconnect(leavePermanently: leavePermanently, completion: completion)
    }

    func reset() {
        guard state != .initialized else {
            return
        }

        room?.delegate = nil
        client.invalidate()

        agentChatState = nil
        systemMessage = nil
        messages = []
        userInput = ""

        client = Client(configuration: configuration, delegate: self)
        room = nil
        state = .initialized
    }
}

extension Chat: ClientDelegate {
    func state(client: Client, state: XMPPProtocolState, previous: XMPPProtocolState) {
        switch state {
        case .failed:
            self.state = .error
        case .terminating:
            self.state = .closing
            systemMessage = SystemMessage(type: .closedStatus)
        case .terminated:
            self.state = .closed
            systemMessage = SystemMessage(type: .closedStatus)
        default:
            break
        }
    }

    func error(client: Client, internal error: XMPPInternalError) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }

        os_log("%@", log: errorLog, "\(error)")
        state = .error
        client.invalidate()
        systemMessage = SystemMessage(type: .internalError(error.errorDescription))
    }

    func error(client: Client, protocol error: XMPPProtocolError) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }

        os_log("%@", log: errorLog, "\(error)")
        state = .error
        client.invalidate()

        systemMessage = SystemMessage(type: .internalError(nil))
    }

    func error(client: Client, transport error: XMPPTransportError) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }

        os_log("%@", log: errorLog, "\(error)")
        state = .error
        client.invalidate()

        switch error {
        case .connection:
            systemMessage = SystemMessage(type: .connectionError)
        case .timeout:
            systemMessage = SystemMessage(type: .connectionError)
        case .parse, .proto:
            systemMessage = SystemMessage(type: .connectionFailure)
        }
    }

    func message(client: Client, sender: XMPPJid, text: String) {
        // Shouldn't happen!
    }

    func queued(client: Client, workgroup: Workgroup) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        workgroup.delegate = self
    }
}

extension Chat: WorkgroupDelegate {
    func joined(workgroup: Workgroup, success: Bool) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        state = .queued
        systemMessage = SystemMessage(type: .queuedStatus)
    }

    func notification(workgroup: Workgroup, text: String) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        systemMessage = SystemMessage(type: .literal(text))
    }

    func invite(workgroup: Workgroup, room: Room) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        room.delegate = self
        room.set(available: true)
        self.room = room
        delegate?.onState(state)
    }
}

extension Chat: RoomDelegate {
    func affiliation(room: Room, for occupant: Room.Occupant) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        switch occupant.affiliation {
        case .owner, .admin, .member:
            if state != .active && occupant.role == .agent {
                state = .active
                systemMessage = nil
            }
        case .none, .outcast:
            if occupant.role == .user {
                client.disconnect(leavePermanently: true)
            }
        }
    }

    func chatstate(room: Room, for occupant: Room.Occupant) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        agentChatState = AgentState(state: occupant.state, timestamp: Date())
    }

    func chatStatus(room: Room, online: Bool) {
        delegate?.onStatus(online: online)
    }

    func message(room: Room, message msg: Room.Message) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        append(message: msg, notify: true)
    }

    func communicationMessages(communicationId: String?, room: Room, messages: [Room.Message]) {
        messages.forEach { self.append(message: $0) }
        messagesDelegate?.onHistoryMessages(messages, communicationId: communicationId)
    }

    func updateMessageState(room: Room, messageState: Room.Message.State, id: String?) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        if messageState == .delivered || messageState == .read {
            // If there is an id, update it and all the previous sent/delivered messages.
            // Otherwise, update all sent/delivered messages.
            let lastIndex = messages.lastIndex { $0.id == id } ?? messages.count-1
            messages[0...lastIndex].filter {
                $0.state != messageState && ($0.state == .sent || $0.state == .delivered)
            }.forEach {
                $0.state = messageState
                messagesDelegate?.onMessageStateUpdate($0)
            }
        } else if messageState != .pending, let msg = messages.first(where: { $0.id == id }) {
            msg.state = messageState
            messagesDelegate?.onMessageStateUpdate(msg)
        }
    }

    func updateMessageInfo(room: Room, message msg: Room.Message) {
        guard state != .closing && state != .closed && state != .error else {
            return
        }
        guard let messageIndex = (messages.lastIndex { $0.id == msg.id }) else {
            return
        }
        messages[messageIndex] = msg
        messagesDelegate?.onUpdatedMessages()
    }
}

extension Chat: XMPPClientAuthenticationDelegate {
    public func xmppClient(_ client: XMPPClientBase, didReceiveAuthenticationMethod method: AuthenticationMethod, completionHandler: @escaping (AuthenticationResponse) -> Void) {
        authenticationDelegate?.chat(self, didReceiveAuthenticationMethod: method, completionHandler: completionHandler)
    }
}

private extension Chat {
    func append(message: Room.Message, notify: Bool = false) {
        let insertIndex = messages.firstIndex {
            $0.timestamp > message.timestamp
        } ?? messages.endIndex
        messages.insert(message, at: insertIndex)

        if notify {
            messagesDelegate?.onNewMessage(message)
            NotificationCenter.default
                .post(name: Chat.Notifications.incomingMessage, object: self)
        }
    }

    func notifyStateObservers() {
        NotificationCenter.default
            .post(name: Chat.Notifications.stateTransition, object: self)
    }
}

