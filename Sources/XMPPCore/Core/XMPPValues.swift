// Copyright © 2020 Nomasystems S.L. All rights reserved.

import Foundation

public enum XMPPNamespace: String {
    case CLIENT         = "jabber:client"
    case SERVER         = "jabber:server"
    case ROSTER         = "jabber:iq:roster"
    case SASL           = "urn:ietf:params:xml:ns:xmpp-sasl"
    case BIND           = "urn:ietf:params:xml:ns:xmpp-bind"
    case SESSION        = "urn:ietf:params:xml:ns:xmpp-session"
    case SLOT_REQUEST   = "urn:xmpp:http:upload:0"
    case STREAM         = "http://etherx.jabber.org/streams"
    case BOSH           = "http://jabber.org/protocol/httpbind"
    case XBOSH          = "urn:xmpp:xbosh"
    case DISCO_ITEMS    = "http://jabber.org/protocol/disco#items"
    case DISCO_INFO     = "http://jabber.org/protocol/disco#info"
    case WORKGROUP      = "http://jabber.org/protocol/workgroup"
    case MUC            = "http://jabber.org/protocol/muc"
    case MUC_ROOMS      = "http://jabber.org/protocol/muc#rooms"
    case MUC_USER       = "http://jabber.org/protocol/muc#user"
    case MUC_ADMIN      = "http://jabber.org/protocol/muc#admin"
    case MUC_FEAT       = "http://jabber.org/features/muc"
    case CHATSTATE      = "http://jabber.org/protocol/chatstates"
    case MESSAGES       = "http://jabber.org/protocol/messages"
    case Undefined      = "undefined"
}

public enum XMPPTransportState {
    case disconnecting
    case disconnected
    case connecting
    case connected
    case failed
}

public enum XMPPTransportError {
    case connection(NSError)
    case timeout
    case proto
    case parse

    static func == (lhs: XMPPTransportError, rhs: XMPPTransportError) -> Bool {
        switch (lhs, rhs) {
        case (.connection(let lherror), .connection(let rherror)):
            return lherror.code == rherror.code
        case (.timeout, .timeout):
            return true
        case (.proto, .proto):
            return true
        case (.parse, .parse):
            return true
        default:
            return false
        }
    }
}

public enum XMPPProtocolState {
    case terminated
    case terminating
    case connecting
    case active
    case failed
}

public enum XMPPProtocolError {
    case stream(String)
    case incomplience
    case bind
    case session
    case authentication
}

public enum XMPPInternalError: LocalizedError {
    case state
    case workgroup(description: String? = nil)

    public var errorDescription: String? {
        switch self {
        case .state:
            return nil
        case .workgroup(let description):
            return description
        }
    }
}
