// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public struct XMPPJid: Equatable {
    public let username: String
    public let domain: String
    public let resource: String

    public init?(username: String, domain: String, resource: String = "") {
        if domain.isEmpty {
            return nil
        }

        self.username = username
        self.domain = domain
        self.resource = resource
    }

    public init(jid: XMPPJid, resource: String = "") {
        self.username = jid.username
        self.domain = jid.domain
        self.resource = resource
    }

    public init?(string: String) {
        var state = ParserState.usertoken
        var token = ""
        var username = ""
        var domain = ""
        var resource = ""

        for s in string.unicodeScalars {
            switch state {
            case .usertoken where s == "@":
                username = token
                state = .domaintoken
                token = ""
            case .domaintoken where s == "/":
                domain = token
                state = .resourcetoken
                token = ""
            default:
                token.append(Character(s))
            }
        }

        switch state {
        case .usertoken, .domaintoken:
            domain = token
        case .resourcetoken:
            resource = token
        }

        if domain.isEmpty {
            return nil
        }

        self.username = username
        self.domain = domain
        self.resource = resource
    }

    public var isBare: Bool {
        return resource.isEmpty
    }

    public func asBare() -> XMPPJid {
        return XMPPJid(username: username, domain: domain, resource: "")!
    }

    public func asHost() -> XMPPJid {
        return XMPPJid(username: "", domain: domain, resource: "")!
    }

    public static func == (lhs: XMPPJid, rhs: XMPPJid) -> Bool {
        guard lhs.domain == rhs.domain, lhs.username == rhs.username else { return false }
        return lhs.resource == rhs.resource
        || lhs.resource.isEmpty || rhs.resource.isEmpty
    }

    private enum ParserState {
        case usertoken
        case domaintoken
        case resourcetoken
    }
}

extension XMPPJid: CustomStringConvertible {
    public var description: String {
        return asString()
    }
}

private extension XMPPJid {
    func asString() -> String {
        if username.isEmpty {
            return domain
        }
        let bare = username + "@" + domain
        return resource.isEmpty ? bare : bare + "/" + resource
    }
}
