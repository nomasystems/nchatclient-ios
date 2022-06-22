// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public enum XMPPIqType {
    case set
    case get
    case error
    case result

    init?(str: String) {
        switch str {
        case "get":
            self = .get
        case "set":
            self = .set
        case "result":
            self = .result
        case "error":
            self = .error
        default:
            return nil
        }
    }

    func encode() -> String {
        switch self {
        case .get:
            return "get"
        case .set:
            return "set"
        case .result:
            return "result"
        case .error:
            return "error"
        }
    }
}

public struct XMPPIq: XMPPStanza {
    public let type: XMPPIqType
    public let id: String
    public let from: XMPPJid?
    public let to: XMPPJid?
    public let data: [XMLParserEl]

    public init(type: XMPPIqType, id: String, from: XMPPJid? = nil, to: XMPPJid? = nil, data: [XMLParserEl] = []) {
        self.type = type
        self.id = id
        self.from = from
        self.to = to
        self.data = data
    }
}

extension XMPPIq {
    init?(from element: XMLParserEl) {
        guard case let .node("iq", _, attributes, children) = element,
              let id = attributes["id"],
              let type = attributes["type"],
              let iqType = XMPPIqType(str: type)
        else { return nil }
        self.init(type: iqType, id: id,
                  from: attributes["from"].flatMap({from in XMPPJid(string: from)}),
                  to: attributes["to"].flatMap({to in XMPPJid(string: to)}),
                  data: children
        )
    }

    func encode() -> XMLParserEl {
        var attributes = [
            "id": self.id,
            "type": self.type.encode()
        ]

        if let to = self.to {
            attributes["to"] = to.description
        }

        if let from = self.from {
            attributes["from"] = from.description
        }

        return XMLParserEl.node(
            name: "iq",
            namespace: .CLIENT,
            attributes: attributes,
            children: self.data
        )
    }
}
