// Copyright © 2022 Nomasystems S.L. All rights reserved.

import Foundation

public struct XMPPPresence: XMPPStanza {
    public let type: String
    public let id: String
    public let from: XMPPJid?
    public let to: XMPPJid?
    public let data: [XMLParserEl]

    public init(type: String = "", id: String = "", from: XMPPJid? = nil, to: XMPPJid? = nil,
                data: [XMLParserEl] = []) {
        self.type = type
        self.id = id
        self.from = from
        self.to = to
        self.data = data
    }
}

extension XMPPPresence {
    init?(from element: XMLParserEl) {
        guard case let .node("presence", _, attributes, children) = element else { return nil }
        self.init(
            type: attributes["type"] ?? "",
            id: attributes["id"] ?? "",
            from: attributes["from"].flatMap({from in XMPPJid(string: from)}),
            to: attributes["to"].flatMap({to in XMPPJid(string: to)}),
            data: children
        )
    }

    func encode() -> XMLParserEl {
        var attributes = [String: String]()

        if !type.isEmpty {
            attributes["type"] = type
        }

        if !id.isEmpty {
            attributes["id"] = id
        }

        if let to = self.to {
            attributes["to"] = to.description
        }

        if let from = self.from {
            attributes["from"] = from.description
        }

        return XMLParserEl.node(
            name: "presence",
            namespace: .CLIENT,
            attributes: attributes,
            children: self.data
        )
    }
}
