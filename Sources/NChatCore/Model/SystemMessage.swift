// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public class SystemMessage {
    public let type: MessageType
    public let timestamp: Date

    init(type: MessageType, timestamp: Date = Date()) {
        self.type = type
        self.timestamp = timestamp
    }

    public enum MessageType {
        case closedInactivity
        case closedStatus
        case connectionError
        case connectionFailure
        case internalError(String?)
        case literal(String)
        case pendingStatus
        case queuedStatus
    }

    enum Style {
        case standard
        case autoreply
        case disconnected
    }
}
